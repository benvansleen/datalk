{
  flake.modules.kubernetes.cloudnative-pg =
    {
      config,
      lib,
      charts,
      ...
    }:
    {
      options.modules.cloudnative-pg = with lib; {
        enable = mkEnableOption "cloudnative-pg";
        namespace = mkOption {
          type = types.str;
          default = "cnpg-system";
        };
      };

      config =
        let
          cfg = config.modules.cloudnative-pg;
        in
        lib.mkIf cfg.enable {
          nixidy.applicationImports = [ ./_generated/cloudnative-pg.nix ];

          applications = {
            cloudnative-pg = {
              inherit (cfg) namespace;
              createNamespace = true;

              helm.releases.cloudnative-pg = {
                chart = charts.cloudnative-pg.cloudnative-pg;
                values = {
                  crds.create = true;
                  monitoring = {
                    podMonitorEnabled = false;
                    grafanaDashboard.create = false;
                  };
                  webhook = {
                    mutating.failurePolicy = "Ignore";
                    validating.failurePolicy = "Ignore";
                  };
                };
              };
            };
            datalk.resources.clusters.datalk-db.spec = {
              instances = 1;
              bootstrap.initdb = {
                database = "datalk";
                owner = "datalk";
              };
              storage.size = "1Gi";
            };
          };
        };
    };
}
