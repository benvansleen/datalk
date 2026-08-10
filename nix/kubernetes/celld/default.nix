{ self, ... }:

{
  flake.modules.kubernetes.celld =
    { config, lib, ... }:
    {
      options.modules.celld = with lib; {
        enable = mkEnableOption "celld";
        image = mkOption {
          type = types.str;
          default = "ghcr.io/denoland/celld:0.1.0";
        };
        deploySourceImage = mkOption {
          type = types.str;
        };
        liveOrigin = mkOption {
          type = types.str;
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
        in
        lib.mkIf cfg.enable {
          modules.celld.deploymentEnv = workerEnv ++ storageEnv;
          applications.celld = {
            namespace = "datalk";
            createNamespace = true;
            resources = {
              services.celld.spec = {
                type = "ClusterIP";
                selector.app = "celld";
                ports.http = {
                  port = 80;
                  targetPort = "http";
                };
              };

              deployments.celld.spec = {
                replicas = 1;
                selector.matchLabels.app = "celld";
                template = {
                  metadata.labels.app = "celld";
                  spec = {
                    volumes = {
                      app.emptyDir = { };
                    };
                    initContainers =
                      (lib.optionalAttrs (!config.modules.celld.dev.enable) {
                        "00-copy-worker" = {
                          image = cfg.deploySourceImage;
                          command = [
                            "/bin/cp"
                            "-r"
                            "/app/."
                            "/work"
                          ];
                          volumeMounts = [
                            {
                              name = "app";
                              mountPath = "/work";
                            }
                          ];
                        };
                      })
                      // {
                        "15-create-bucket" = {
                          image = "curlimages/curl:8.17.0";
                          command = [
                            "sh"
                            "-c"
                            ''
                              status="$(curl --silent --output /dev/null --write-out '%{http_code}' --request PUT http://storage-s3:8333/datalk-celld)"
                              test "$status" = 200 -o "$status" = 409
                            ''
                          ];
                        };
                        "20-deploy-worker" = {
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
                              value = "/bin/esbuild";
                            }
                          ];
                          volumeMounts = [
                            {
                              name = "app";
                              mountPath = "/app";
                            }
                          ];
                        };
                      };
                    containers.celld = {
                      inherit (cfg) image;
                      imagePullPolicy = "Always";
                      ports.http.containerPort = 8080;
                      readinessProbe = {
                        httpGet = {
                          path = "/live/health";
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
                          name = "POD_IP";
                          valueFrom.fieldRef.fieldPath = "status.podIP";
                        }
                        {
                          name = "CELLD_ADVERTISE";
                          value = "$(POD_IP):8080";
                        }
                      ]
                      ++ cfg.deploymentEnv;
                    };
                  };
                };
              };
            };
          };
        };
    };
}
