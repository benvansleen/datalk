{ self, ... }:

{
  flake.modules.kubernetes.lis-python-server =
    { config, lib, ... }:
    {
      options.modules.python-server = with lib; {
        enable = mkEnableOption "Lisette python-server";
        image = mkOption {
          type = types.str;
        };
        workerImage = mkOption {
          type = types.str;
        };
        port = mkOption {
          type = types.port;
          default = 8000;
        };
        workerPort = mkOption {
          type = types.port;
          default = 8001;
        };
        datasetHostPath = mkOption {
          type = types.str;
        };
        datasetGcsBucket = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        checkpointStorageClass = mkOption {
          type = types.str;
          default = "local-path";
        };
        maxWorkers = mkOption {
          type = types.ints.positive;
          default = 6;
        };
      };

      config =
        let
          cfg = config.modules.python-server;
          controllerLabel = "python-server";
          controllerServiceAccount = "python-server-controller";
          executionNamespace = "datalk-execution";
          workerLabel = "datalk-python-worker";
          datasetClaim = "datalk-datasets";
          datasetVolume = "datalk-datasets-local";
          controllerConfig = builtins.toJSON {
            server = {
              address = "0.0.0.0:${toString cfg.port}";
              max_request_bytes = 1048576;
              shutdown_timeout = "10s";
            };
            kubernetes = {
              api_url = "https://kubernetes.default.svc";
              execution_namespace = executionNamespace;
              token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token";
              ca_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
              request_timeout = "10s";
              readiness_poll_interval = "500ms";
            };
            environments = {
              max_active = cfg.maxWorkers;
              startup_timeout = "60s";
              idle_timeout = "15m";
              execution_timeout = "120s";
            };
            worker = {
              image = cfg.workerImage;
              port = cfg.workerPort;
              auth_key_path = "/etc/datalk/worker-auth-key";
              runtime_class = null;
              resources = {
                cpu_request = "250m";
                cpu_limit = "1";
                memory_request = "512Mi";
                memory_limit = "1Gi";
                ephemeral_storage_limit = "256Mi";
              };
            };
            storage = {
              dataset_claim = datasetClaim;
              checkpoint_storage_class = cfg.checkpointStorageClass;
              checkpoint_size = "256Mi";
              use_gcs_fuse = cfg.datasetGcsBucket != null;
            };
            datasets = {
              catalog_path = "/etc/datalk/datasets.json";
              mount_path = "/datasets";
            };
          };
          datasetCatalog = builtins.toJSON [
            {
              name = "College Football 2025";
              relative_path = "cfbd";
            }
          ];
        in
        lib.mkIf cfg.enable {
          applications = {
            python-server = {
              namespace = "datalk";
              createNamespace = true;

              resources = {
                configMaps = {
                  python-server-config.data."config.json" = controllerConfig;
                  python-server-datasets.data."datasets.json" = datasetCatalog;
                };

                ## TODO: move to ESO/local-secrets
                secrets.python-worker-auth = {
                  type = "Opaque";
                  stringData.worker-auth-key = "datalk-local-worker-auth-key-change-me";
                };

                serviceAccounts.${controllerServiceAccount} = { };

                services.python-server.spec = {
                  type = "ClusterIP";
                  selector.app = controllerLabel;
                  ports.http = {
                    inherit (cfg) port;
                    targetPort = "http";
                  };
                };

                deployments.python-server.spec = {
                  replicas = 1;
                  selector.matchLabels.app = controllerLabel;

                  template = {
                    metadata.labels.app = controllerLabel;
                    spec = {
                      serviceAccountName = controllerServiceAccount;
                      securityContext = {
                        runAsNonRoot = true;
                        runAsUser = 1000;
                        runAsGroup = 1000;
                        fsGroup = 1000;
                        seccompProfile.type = "RuntimeDefault";
                      };
                      containers.python-server = {
                        inherit (cfg) image;
                        imagePullPolicy = "Always";
                        ports.http.containerPort = cfg.port;
                        securityContext = {
                          allowPrivilegeEscalation = false;
                          capabilities.drop = [ "ALL" ];
                          readOnlyRootFilesystem = true;
                        };
                        resources = {
                          requests = {
                            cpu = "50m";
                            memory = "64Mi";
                          };
                          limits = {
                            cpu = "500m";
                            memory = "256Mi";
                          };
                        };
                        volumeMounts = {
                          config = {
                            name = "config";
                            mountPath = "/etc/datalk/config.json";
                            subPath = "config.json";
                            readOnly = true;
                          };
                          datasets = {
                            name = "datasets";
                            mountPath = "/etc/datalk/datasets.json";
                            subPath = "datasets.json";
                            readOnly = true;
                          };
                          worker-auth = {
                            name = "worker-auth";
                            mountPath = "/etc/datalk/worker-auth-key";
                            subPath = "worker-auth-key";
                            readOnly = true;
                          };
                          tmp = {
                            name = "tmp";
                            mountPath = "/tmp";
                            readOnly = false;
                          };
                        };
                      };
                      volumes = {
                        config = {
                          name = "config";
                          configMap.name = "python-server-config";
                        };
                        datasets = {
                          name = "datasets";
                          configMap.name = "python-server-datasets";
                        };
                        worker-auth = {
                          name = "worker-auth";
                          secret.secretName = "python-worker-auth";
                        };
                        tmp = {
                          name = "tmp";
                          emptyDir = { };
                        };
                      };
                    };
                  };
                };
              };
            };

            python-execution = {
              namespace = executionNamespace;
              createNamespace = true;

              resources = {
                serviceAccounts.datalk-worker = {
                  automountServiceAccountToken = false;
                  metadata.annotations."iam.gke.io/gcp-service-account" =
                    "datalk-datasets@${self.gcloud.project}.iam.gserviceaccount.com";
                };

                roles.python-server-controller.rules = [
                  {
                    apiGroups = [ "" ];
                    resources = [ "pods" ];
                    verbs = [
                      "list"
                      "create"
                      "delete"
                      "get"
                    ];
                  }
                  {
                    apiGroups = [ "" ];
                    resources = [ "persistentvolumeclaims" ];
                    verbs = [
                      "list"
                      "create"
                      "delete"
                      "get"
                    ];
                  }
                  {
                    apiGroups = [ "" ];
                    resources = [ "serviceaccounts" ];
                    verbs = [ "create" ];
                  }
                ];

                roleBindings.python-server-controller = {
                  roleRef = {
                    apiGroup = "rbac.authorization.k8s.io";
                    kind = "Role";
                    name = "python-server-controller";
                  };
                  subjects = [
                    {
                      kind = "ServiceAccount";
                      name = controllerServiceAccount;
                      namespace = "datalk";
                    }
                  ];
                };

                persistentVolumes.${datasetVolume}.spec = {
                  capacity.storage = "1Gi";
                  accessModes = [ "ReadOnlyMany" ];
                  persistentVolumeReclaimPolicy = "Retain";
                  storageClassName = "";
                }
                // (
                  if cfg.datasetGcsBucket != null then
                    {
                      mountOptions = [ "implicit-dirs" ];
                      csi = {
                        driver = "gcsfuse.csi.storage.gke.io";
                        volumeHandle = cfg.datasetGcsBucket;
                        readOnly = true;
                        volumeAttributes = {
                          bucketName = cfg.datasetGcsBucket;
                        };
                      };
                    }
                  else
                    {
                      hostPath = {
                        path = cfg.datasetHostPath;
                        type = "Directory";
                      };
                    }
                );

                persistentVolumeClaims.${datasetClaim}.spec = {
                  accessModes = [ "ReadOnlyMany" ];
                  storageClassName = "";
                  volumeName = datasetVolume;
                  resources.requests.storage = "1Gi";
                };

                resourceQuotas.python-workers.spec.hard = {
                  pods = toString cfg.maxWorkers;
                  persistentvolumeclaims = toString (cfg.maxWorkers + 1);
                  "requests.storage" = "3Gi";
                };

                networkPolicies.python-workers.spec = {
                  podSelector.matchLabels."app.kubernetes.io/name" = workerLabel;
                  policyTypes = [
                    "Ingress"
                    "Egress"
                  ];
                  ingress = [
                    {
                      from = [
                        {
                          namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "datalk";
                          podSelector.matchLabels.app = controllerLabel;
                        }
                      ];
                      ports = [
                        {
                          protocol = "TCP";
                          port = cfg.workerPort;
                        }
                      ];
                    }
                  ];
                  # TODO: don't hardcode these ips inline
                  egress =
                    if cfg.datasetGcsBucket != null then
                      [
                        {
                          to = [
                            {
                              ipBlock.cidr = "169.254.169.254/32";
                            }
                          ];
                          ports = [
                            {
                              protocol = "TCP";
                              port = 80;
                            }
                          ];
                        }
                        {
                          to = [
                            {
                              ipBlock.cidr = "199.36.153.8/30";
                            }
                          ];
                          ports = [
                            {
                              protocol = "TCP";
                              port = 443;
                            }
                          ];
                        }
                      ]
                    else
                      [ ];
                };
              };
            };
          };
        };
    };
}
