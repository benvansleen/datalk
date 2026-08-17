{
  flake.modules.kubernetes.datalk-external-secrets =
    { config, lib, ... }:
    {
      options.modules.datalk.runtimeExternalSecret = with lib; {
        enable = mkEnableOption "syncing datalk-runtime with External Secrets Operator";
        storeName = mkOption {
          type = types.str;
          default = "google-secret-manager";
        };
      };

      config =
        let
          cfg = config.modules.datalk.runtimeExternalSecret;
        in
        lib.mkIf cfg.enable {
          applications.datalk.resources.externalSecrets = {
            datalk-runtime = {
              apiVersion = "external-secrets.io/v1";
              kind = "ExternalSecret";
              spec = {
                refreshInterval = "1h";
                secretStoreRef = {
                  name = cfg.storeName;
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
                    secretKey = "INTERNAL_CELL_SECRET";
                    remoteRef.key = "internal-cell-secret";
                  }
                  {
                    secretKey = "INTERNAL_PROJECTION_SECRET";
                    remoteRef.key = "internal-projection-secret";
                  }
                  {
                    secretKey = "OPENAI_API_KEY";
                    remoteRef.key = "openai-api-key";
                  }
                ];
              };
            };
          };
        };
    };
}
