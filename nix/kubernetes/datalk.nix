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
              in
              {
                services.datalk = {
                  metadata.annotations = {
                    "tailscale.com/expose" = "true";
                    "tailscale.com/hostname" = "datalk";
                  };
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
                    spec.containers.datalk = {
                      inherit (cfg) image;
                      imagePullPolicy = "Always";
                      ports.http.containerPort = 3000;

                      env = [
                        {
                          name = "NODE_ENV";
                          value = "production";
                        }
                        {
                          name = "PORT";
                          value = "3000";
                        }
                        {
                          name = "ORIGIN";
                          value = "http://datalk";
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
}
