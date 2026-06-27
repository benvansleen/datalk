{
  flake.modules.kubernetes.python-server =
    { config, lib, ... }:
    {
      options.modules.python-server = with lib; {
        enable = mkEnableOption "python-server";
        image = mkOption {
          type = types.str;
        };
        port = mkOption {
          type = types.port;
          default = 8000;
        };
      };

      config =
        let
          cfg = config.modules.python-server;
          app-label = "python-server";
        in
        lib.mkIf cfg.enable {
          applications.python-server = {
            namespace = "datalk";
            createNamespace = true;

            resources = {
              services.python-server.spec = {
                type = "ClusterIP";
                selector.app = app-label;
                ports.http = {
                  inherit (cfg) port;
                  targetPort = "http";
                };
              };
              deployments.python-server.spec = {
                replicas = 1;
                selector.matchLabels.app = app-label;

                template = {
                  metadata.labels.app = app-label;
                  spec = {
                    containers.python-server = {
                      inherit (cfg) image;
                      imagePullPolicy = "Always";
                      ports.http.containerPort = cfg.port;
                    };
                  };
                };
              };
            };
          };
        };
    };
}
