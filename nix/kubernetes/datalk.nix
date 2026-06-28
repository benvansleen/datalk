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
          type = types.nullOr types.str;
          default = null;
        };
        ingress = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                type = mkOption {
                  type = types.enum [
                    "local"
                    "tailscale"
                  ];
                };
                host = mkOption { type = types.str; };
              };
            }
          );
          default = null;
        };
        runtimeExternalSecret = {
          enable = mkEnableOption "syncing datalk-runtime with External Secrets Operator";
          storeName = mkOption {
            type = types.str;
            default = "google-secret-manager";
          };
        };
        dev = {
          enable = mkEnableOption "hot-reloading UI development mode";
          hostUiPath = mkOption {
            type = types.str;
            default = "/workspace/datalk/ui";
          };
        };
      };

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
                ingressPath = {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "datalk";
                    port.name = "http";
                  };
                };
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
                          command = if cfg.dev.enable then [ "/bin/node" ] else [ "/bin/migrate" ];
                          args = lib.mkIf cfg.dev.enable [ "/app/migrate.mjs" ];
                          workingDir = lib.mkIf cfg.dev.enable "/app";
                          env = dbEnv;
                          volumeMounts = lib.mkIf cfg.dev.enable [
                            {
                              name = "ui-drizzle";
                              mountPath = "/app/drizzle";
                            }
                          ];
                        };
                        containers.datalk = {
                          inherit (cfg) image;
                          imagePullPolicy = "Always";
                          ports.http.containerPort = 3000;
                          command = lib.mkIf cfg.dev.enable [
                            "/bin/node"
                            "/app/node_modules/vite/bin/vite.js"
                            "--host"
                            "0.0.0.0"
                          ];
                          args = lib.mkIf cfg.dev.enable [
                            "--port"
                            "3000"
                          ];
                          workingDir = lib.mkIf cfg.dev.enable "/app";
                          volumeMounts = lib.mkIf cfg.dev.enable [
                            {
                              name = "ui-src";
                              mountPath = "/app/src";
                            }
                            {
                              name = "ui-static";
                              mountPath = "/app/static";
                            }
                            {
                              name = "ui-drizzle";
                              mountPath = "/app/drizzle";
                            }
                            {
                              name = "ui-svelte-config";
                              mountPath = "/app/svelte.config.js";
                            }
                            {
                              name = "ui-vite-config";
                              mountPath = "/app/vite.config.ts";
                            }
                            {
                              name = "ui-tsconfig";
                              mountPath = "/app/tsconfig.json";
                            }
                            {
                              name = "ui-drizzle-config";
                              mountPath = "/app/drizzle.config.ts";
                            }
                          ];

                          env =
                            dbEnv
                            ++ redisEnv
                            ++ lib.optional (cfg.environment != null) {
                              name = "ENVIRONMENT";
                              value = cfg.environment;
                            }
                            ++ [
                              {
                                name = "NODE_ENV";
                                value = if cfg.dev.enable then "development" else "production";
                              }
                            ]
                            ++ lib.optional cfg.dev.enable {
                              name = "CHOKIDAR_USEPOLLING";
                              value = "true";
                            }
                            ++ [
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
                        volumes = lib.mkIf cfg.dev.enable [
                          {
                            name = "ui-src";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/src";
                              type = "Directory";
                            };
                          }
                          {
                            name = "ui-static";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/static";
                              type = "Directory";
                            };
                          }
                          {
                            name = "ui-drizzle";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/drizzle";
                              type = "Directory";
                            };
                          }
                          {
                            name = "ui-svelte-config";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/svelte.config.js";
                              type = "File";
                            };
                          }
                          {
                            name = "ui-vite-config";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/vite.config.ts";
                              type = "File";
                            };
                          }
                          {
                            name = "ui-tsconfig";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/tsconfig.json";
                              type = "File";
                            };
                          }
                          {
                            name = "ui-drizzle-config";
                            hostPath = {
                              path = "${cfg.dev.hostUiPath}/drizzle.config.ts";
                              type = "File";
                            };
                          }
                        ];
                      };
                  };
                };
                ingresses = lib.mkIf (cfg.ingress != null) {
                  datalk.spec = {
                    rules = [
                      {
                        inherit (cfg.ingress) host;
                        http.paths = [ ingressPath ];
                      }
                    ];
                  }
                  // lib.optionalAttrs (cfg.ingress.type == "tailscale") {
                    ingressClassName = "tailscale";
                    tls = [
                      {
                        hosts = [ cfg.ingress.host ];
                      }
                    ];
                  };
                };
              }
              // lib.optionalAttrs cfg.runtimeExternalSecret.enable {
                externalSecrets = {
                  datalk-runtime = {
                    apiVersion = "external-secrets.io/v1";
                    kind = "ExternalSecret";
                    spec = {
                      refreshInterval = "1h";
                      secretStoreRef = {
                        name = cfg.runtimeExternalSecret.storeName;
                        kind = "ClusterSecretStore";
                      };
                      target = {
                        name = "datalk-runtime";
                        creationPolicy = "Owner";
                      };
                      data = [
                        {
                          secretKey = "BETTER_AUTH_SECRET";
                          remoteRef.key = "better-auth-secret";
                        }
                        {
                          secretKey = "OPENAI_API_KEY";
                          remoteRef.key = "openai-api-key";
                        }
                        {
                          secretKey = "REDIS_USER";
                          remoteRef.key = "redis-user";
                        }
                        {
                          secretKey = "REDIS_PASSWORD";
                          remoteRef.key = "redis-password";
                        }
                      ];
                    };
                  };
                };
              };
          };
        };
    };
}
