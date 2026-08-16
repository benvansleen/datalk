{ self, ... }:

{
  flake.modules.kubernetes.celld =
    { config, lib, ... }:
    {
      options.modules.celld = with lib; {
        enable = mkEnableOption "celld";
        image = mkOption {
          type = types.str;
          default = "ghcr.io/denoland/celld:0.2.1";
        };
        deploySourceImage = mkOption {
          type = types.str;
        };
        liveOrigin = mkOption {
          type = types.str;
        };
        replicas = mkOption {
          type = types.ints.positive;
          default = 2;
        };
        deploymentEnv = mkOption {
          type = types.listOf types.attrs;
          readOnly = true;
        };
      };

      imports = with self.modules.kubernetes; [ celld-dev ];

      config =
        let
          cfg = config.modules.celld;
          secret = key: {
            valueFrom.secretKeyRef = {
              name = "datalk-runtime";
              inherit key;
            };
          };
          workerEnv = [
            ({ name = "CELLD_VAR_INTERNAL_CELL_SECRET"; } // secret "INTERNAL_CELL_SECRET")
            ({ name = "CELLD_VAR_INTERNAL_PROJECTION_SECRET"; } // secret "INTERNAL_PROJECTION_SECRET")
            ({ name = "CELLD_VAR_OPENAI_API_KEY"; } // secret "OPENAI_API_KEY")
            {
              name = "CELLD_VAR_LIVE_ORIGIN";
              value = cfg.liveOrigin;
            }
            {
              name = "CELLD_VAR_PYTHON_SERVER_URL";
              value = "http://python-server.datalk.svc.cluster.local:8000";
            }
            {
              name = "CELLD_VAR_INTERNAL_API_URL";
              value = "http://datalk.datalk.svc.cluster.local";
            }
          ];
          storageEnv = [
            # SeaweedFS uses the S3 protocol but has no external cloud credentials.
            {
              name = "AWS_ACCESS_KEY_ID";
              value = "celld";
            }
            {
              name = "AWS_SECRET_ACCESS_KEY";
              value = "celld";
            }
          ];
          isDev = config.modules.celld.dev.enable;
          publicationId = builtins.substring 0 12 (
            builtins.hashString "sha256" "v3:${cfg.image}:${cfg.deploySourceImage}"
          );
          publicationName = "celld-deploy-${publicationId}";
          createBucket = {
            image = "curlimages/curl:8.17.0";
            command = [
              "sh"
              "-c"
              ''
                until status="$(curl --silent --output /dev/null --write-out '%{http_code}' --request PUT http://storage-s3:8333/datalk-celld)" \
                  && { [ "$status" = 200 ] || [ "$status" = 409 ]; }; do
                  echo "waiting for SeaweedFS S3"
                  sleep 2
                done
              ''
            ];
          };
          deployWorker = {
            inherit (cfg) image;
            command = [
              "celld"
              "deploy"
              "/app"
              "--bucket"
              "s3://datalk-celld"
              "--endpoint"
              "http://storage-s3:8333"
              "--region"
              "us-east-1"
            ];
            env = cfg.deploymentEnv ++ [
              {
                name = "CELLD_ESBUILD";
                value = "/app/esbuild";
              }
            ];
            volumeMounts = [
              {
                name = "app";
                mountPath = "/app";
              }
              {
                name = "tmp";
                mountPath = "/tmp";
              }
            ];
          };
          publicationUrl = "http://storage-s3:8333/datalk-celld/.deployments/${publicationId}";
          waitForPublication = {
            image = "curlimages/curl:8.17.0";
            command = [
              "sh"
              "-c"
              ''
                until curl --fail --silent --output /dev/null ${publicationUrl}; do
                  echo "waiting for celld publication ${publicationId}"
                  sleep 2
                done
              ''
            ];
          };
        in
        lib.mkIf cfg.enable {
          modules.celld.deploymentEnv = workerEnv ++ storageEnv;
          applications.celld = {
            namespace = "datalk";
            createNamespace = true;
            resources =
              lib.recursiveUpdate
                {
                  services.celld.spec = {
                    type = "ClusterIP";
                    selector.app = "celld";
                    ports.http = {
                      port = 80;
                      targetPort = "http";
                    };
                  };

                  deployments.celld.spec = {
                    replicas = if isDev then 1 else cfg.replicas;
                    strategy =
                      if isDev then
                        { type = "Recreate"; }
                      else
                        {
                          type = "RollingUpdate";
                          rollingUpdate = {
                            maxUnavailable = 0;
                            maxSurge = 1;
                          };
                        };
                    selector.matchLabels.app = "celld";
                    template = {
                      metadata = {
                        labels.app = "celld";
                      }
                      // lib.optionalAttrs (!isDev) {
                        annotations = {
                          "datalk.dev/celld-publication" = publicationId;
                        };
                      };
                      spec = {
                        volumes.tmp.emptyDir = { };
                        initContainers =
                          if isDev then
                            {
                              "15-create-bucket" = createBucket;
                              "20-deploy-worker" = deployWorker;
                            }
                          else
                            {
                              wait-for-publication = waitForPublication;
                            };
                        topologySpreadConstraints = lib.optionals (!isDev) [
                          {
                            maxSkew = 1;
                            topologyKey = "kubernetes.io/hostname";
                            whenUnsatisfiable = "ScheduleAnyway";
                            labelSelector.matchLabels.app = "celld";
                          }
                        ];
                        containers.celld = {
                          inherit (cfg) image;
                          imagePullPolicy = "Always";
                          ports = {
                            http.containerPort = 8080;
                            internal.containerPort = 8081;
                          };
                          readinessProbe = {
                            httpGet = {
                              path = "/__celld/health";
                              port = "http";
                            };
                            initialDelaySeconds = 1;
                            periodSeconds = 2;
                          };
                          env = [
                            {
                              name = "CELLD_BUCKET";
                              value = "s3://datalk-celld";
                            }
                            {
                              name = "S3_ENDPOINT";
                              value = "http://storage-s3:8333";
                            }
                            {
                              name = "AWS_REGION";
                              value = "us-east-1";
                            }
                            {
                              name = "CELLD_ADDR";
                              value = "0.0.0.0:8080";
                            }
                            {
                              name = "CELLD_INTERNAL_ADDR";
                              value = "0.0.0.0:8081";
                            }
                            {
                              name = "POD_IP";
                              valueFrom.fieldRef.fieldPath = "status.podIP";
                            }
                            {
                              name = "CELLD_ADVERTISE";
                              value = "$(POD_IP):8081";
                            }
                          ]
                          ++ cfg.deploymentEnv;
                          volumeMounts = [
                            {
                              name = "tmp";
                              mountPath = "/tmp";
                            }
                          ];
                        };
                      };
                    };
                  };
                }
                (
                  lib.optionalAttrs (!isDev) {
                    jobs.${publicationName}.spec = {
                      backoffLimit = 6;
                      template.spec = {
                        restartPolicy = "OnFailure";
                        volumes = {
                          app.emptyDir = { };
                          tmp.emptyDir = { };
                        };
                        initContainers = {
                          copy-worker = {
                            image = cfg.deploySourceImage;
                            command = [
                              "/bin/cp"
                              "-rL"
                              "/app/."
                              "/bin/esbuild"
                              "/work"
                            ];
                            volumeMounts = [
                              {
                                name = "app";
                                mountPath = "/work";
                              }
                            ];
                          };
                          create-bucket = createBucket;
                          deploy-worker = deployWorker;
                        };
                        containers.publish-marker = {
                          image = "curlimages/curl:8.17.0";
                          command = [
                            "curl"
                            "--fail-with-body"
                            "--retry"
                            "60"
                            "--retry-all-errors"
                            "--retry-delay"
                            "2"
                            "--request"
                            "PUT"
                            "--data-binary"
                            publicationId
                            publicationUrl
                          ];
                        };
                      };
                    };
                    podDisruptionBudgets.celld.spec = {
                      minAvailable = 1;
                      selector.matchLabels.app = "celld";
                    };
                  }
                );
          };
        };
    };
}
