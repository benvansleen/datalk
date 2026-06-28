{ self, ... }:

{
  flake.modules.kubernetes.datalk =
    { config, lib, ... }:
    {
      options.modules.datalk = with lib; {
        enable = mkEnableOption "datalk";
        image = mkOption {
          type = types.str;
          example = "us-east4-docker.pkg.dev/datalk-499418/datalk/datalk:git-dirty";
        };
        publicUrl = mkOption {
          type = types.str;
          example = "http://datalk.localhost:8080";
        };
        environment = mkOption {
          type = types.str;
          default = "production";
        };
      };

      imports = with self.modules.kubernetes; [
        datalk-dev
        datalk-external-secrets
        datalk-ingress
      ];

      config =
        let
          cfg = config.modules.datalk;
        in
        lib.mkIf cfg.enable {
          applications.datalk = {
            namespace = "datalk";
            createNamespace = true;

            resources =
              let
                app-label = "datalk";
              in
              {
                services.datalk = {
                  spec = {
                    type = "ClusterIP";
                    selector.app = app-label;
                    ports.http = {
                      port = 80;
                      targetPort = "http";
                    };
                  };
                };
                deployments.datalk.spec = {
                  replicas = 1;
                  selector.matchLabels.app = app-label;

                  template = {
                    metadata.labels.app = app-label;
                    spec =
                      let
                        dbEnv = [
                          {
                            name = "DB_USER";
                            valueFrom.secretKeyRef = {
                              name = "datalk-db-app";
                              key = "username";
                            };
                          }
                          {
                            name = "DB_PASSWORD";
                            valueFrom.secretKeyRef = {
                              name = "datalk-db-app";
                              key = "password";
                            };
                          }
                          {
                            name = "DB_HOST";
                            valueFrom.secretKeyRef = {
                              name = "datalk-db-app";
                              key = "host";
                            };
                          }
                          {
                            name = "DB_PORT";
                            valueFrom.secretKeyRef = {
                              name = "datalk-db-app";
                              key = "port";
                            };
                          }
                          {
                            name = "DB_NAME";
                            valueFrom.secretKeyRef = {
                              name = "datalk-db-app";
                              key = "dbname";
                            };
                          }
                        ];
                        redisEnv = with config.modules.valkey; [
                          {
                            name = "REDIS_HOST";
                            value = "valkey";
                          }
                          {
                            name = "REDIS_PORT";
                            value = toString port;
                          }
                          {
                            name = "REDIS_USER";
                            valueFrom.secretKeyRef = {
                              name = secretName;
                              key = userKey;
                            };
                          }
                          {
                            name = "REDIS_PASSWORD";
                            valueFrom.secretKeyRef = {
                              name = secretName;
                              key = passwordKey;
                            };
                          }
                        ];
                      in
                      {
                        initContainers.migrate = {
                          inherit (cfg) image;
                          imagePullPolicy = "Always";
                          command = [ "/bin/migrate" ];
                          env = dbEnv;
                        };
                        containers.datalk = {
                          inherit (cfg) image;
                          imagePullPolicy = "Always";
                          ports.http.containerPort = 3000;

                          env =
                            dbEnv
                            ++ redisEnv
                            ++ [
                              {
                                name = "ENVIRONMENT";
                                value = cfg.environment;
                              }
                              {
                                name = "NODE_ENV";
                                value = cfg.environment;
                              }
                              {
                                name = "PORT";
                                value = "3000";
                              }
                              {
                                name = "ORIGIN";
                                value = cfg.publicUrl;
                              }
                              {
                                name = "BETTER_AUTH_URL";
                                value = cfg.publicUrl;
                              }
                              {
                                name = "BETTER_AUTH_SECRET";
                                valueFrom.secretKeyRef = {
                                  name = "datalk-runtime";
                                  key = "BETTER_AUTH_SECRET";
                                };
                              }
                              {
                                name = "PYTHON_SERVER_HOST";
                                value = "python-server";
                              }
                              {
                                name = "PYTHON_SERVER_PORT";
                                value = toString config.modules.python-server.port;
                              }
                              {
                                name = "OPENAI_API_KEY";
                                valueFrom.secretKeyRef = {
                                  name = "datalk-runtime";
                                  key = "OPENAI_API_KEY";
                                };
                              }
                            ];

                          # resources = {
                          # requests = {
                          #   cpu = "100m";
                          #   memory = "2Gi";
                          # };
                          # limits = {
                          #   cpu = "500m";
                          #   memory = "3Gi";
                          # };
                          # };
                        };
                      };
                  };
                };
              };
          };
        };
    };
}
