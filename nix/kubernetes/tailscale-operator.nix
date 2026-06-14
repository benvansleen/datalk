{
  flake.modules.kubernetes.tailscale-operator =
    {
      config,
      lib,
      charts,
      ...
    }:
    {
      options.modules.tailscale-operator = with lib; {
        enable = mkEnableOption "tailscale-operator";
      };

      config =
        let
          cfg = config.modules.tailscale-operator;
        in
        lib.mkIf cfg.enable {
          nixidy.applicationImports = [ ../_generated/tailscale-operator.nix ];

          applications.tailscale-operator = {
            namespace = "tailscale";
            createNamespace = true;

            helm.releases.tailscale-operator = {
              chart = charts.tailscale.tailscale-operator;
              values = {
                oauth.secretName = "operator-oauth";
                operatorConfig.hostname = "datalk-tailscale-operator";
              };
            };

            resources = {
              externalSecrets.tailscale-oauth = {
                apiVersion = "external-secrets.io/v1";
                kind = "ExternalSecret";

                spec = {
                  refreshInterval = "1h";

                  secretStoreRef = {
                    name = "google-secret-manager";
                    kind = "ClusterSecretStore";
                  };

                  target = {
                    name = "operator-oauth";
                    creationPolicy = "Owner";
                  };

                  data = [
                    {
                      secretKey = "client_id";
                      remoteRef.key = "tailscale-oauth-client-id";
                    }
                    {
                      secretKey = "client_secret";
                      remoteRef.key = "tailscale-oauth-client-secret";
                    }
                  ];
                };
              };
            };
          };
        };
    };
}
