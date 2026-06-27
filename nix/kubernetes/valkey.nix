{
  flake.modules.kubernetes.valkey =
    { config, lib, ... }:
    {
      options.modules.valkey = with lib; {
        enable = mkEnableOption "valkey";
        image = mkOption {
          type = types.str;
          default = "valkey/valkey:9.1-alpine";
        };
        port = mkOption {
          type = types.port;
          default = 6379;
        };
        secretName = mkOption {
          type = types.str;
          default = "datalk-runtime";
        };
        userKey = mkOption {
          type = types.str;
          default = "REDIS_USER";
        };
        passwordKey = mkOption {
          type = types.str;
          default = "REDIS_PASSWORD";
        };
      };

      config =
        let
          cfg = config.modules.valkey;
          app-label = "valkey";
        in
        lib.mkIf cfg.enable {
          applications.valkey = {
            namespace = "datalk";
            createNamespace = true;

            resources = {
              services.valkey.spec = {
                type = "ClusterIP";
                selector.app = app-label;
                ports.redis = {
                  inherit (cfg) port;
                  targetPort = "redis";
                };
              };

              deployments.valkey.spec = {
                replicas = 1;
                selector.matchLabels.app = app-label;

                template = {
                  metadata.labels.app = app-label;
                  spec.containers.valkey = {
                    inherit (cfg) image;
                    imagePullPolicy = "IfNotPresent";
                    command = [
                      "sh"
                      "-c"
                      ''exec valkey-server --bind 0.0.0.0 --port ${toString cfg.port} --requirepass "$REDIS_PASSWORD"''
                    ];
                    ports.redis.containerPort = cfg.port;
                    env = [
                      {
                        name = "REDIS_PASSWORD";
                        valueFrom.secretKeyRef = {
                          name = cfg.secretName;
                          key = cfg.passwordKey;
                        };
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
