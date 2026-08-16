{
  flake.modules.kubernetes.seaweedfs =
    {
      config,
      lib,
      charts,
      ...
    }:
    {
      options.modules.seaweedfs = with lib; {
        enable = mkEnableOption "SeaweedFS S3 storage via seaweedfs-operator";
        namespace = mkOption {
          type = types.str;
          default = "datalk";
        };
      };

      config =
        let
          cfg = config.modules.seaweedfs;
        in
        lib.mkIf cfg.enable {
          nixidy.applicationImports = [ ./_generated/seaweedfs-operator.nix ];

          applications = {
            seaweedfs-operator = {
              inherit (cfg) namespace;
              createNamespace = true;

              helm.releases.seaweedfs-operator = {
                chart = charts.seaweedfs-operator.seaweedfs-operator;
                values = {
                  webhook.enabled = false;
                };
              };
            };

            datalk.resources.seaweeds.storage.spec = {
              image = "chrislusf/seaweedfs:4.41";
              volumeServerDiskCount = 1;
              master = {
                replicas = 1;
              };
              volume = {
                replicas = 1;
                requests.storage = "1Gi";
              };
              filer = {
                replicas = 1;
              };
              s3 = {
                replicas = 1;
              };
            };
          };
        };
    };
}
