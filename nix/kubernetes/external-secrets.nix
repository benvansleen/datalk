{ self, ... }:

{
  flake.modules.kubernetes.external-secrets =
    {
      config,
      lib,
      charts,
      ...
    }:
    {
      options.modules.external-secrets = with lib; {
        enable = mkEnableOption "External Secrets Operator";
      };

      config =
        let
          cfg = config.modules.external-secrets;
        in
        lib.mkIf cfg.enable {
          nixidy.applicationImports = [ ./_generated/external-secrets.nix ];

          applications.external-secrets = {
            namespace = "external-secrets";
            createNamespace = true;

            helm.releases.external-secrets = {
              chart = charts.external-secrets.external-secrets;
              values = {
                serviceAccount = {
                  create = true;
                  name = "external-secrets";
                  annotations = {
                    "iam.gke.io/gcp-service-account" =
                      "external-secrets@${self.gcloud.project}.iam.gserviceaccount.com";
                  };
                };
              };
            };

            resources.clusterSecretStores.google-secret-manager = {
              apiVersion = "external-secrets.io/v1";
              kind = "ClusterSecretStore";
              metadata.name = "google-secret-manager";
              spec.provider.gcpsm = {
                projectID = self.gcloud.project;
                auth.workloadIdentity = {
                  clusterProjectID = self.gcloud.project;
                  clusterLocation = self.gcloud.zone;
                  clusterName = "datalk";
                  serviceAccountRef = {
                    name = "external-secrets";
                    namespace = "external-secrets";
                  };
                };
              };
            };
          };
        };
    };
}
