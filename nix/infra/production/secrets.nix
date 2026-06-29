{ self, ... }:

{
  flake.modules.infra.production-secrets = {
    resource = {
      google_project_service.secretmanager = {
        inherit (self.gcloud) project;
        service = "secretmanager.googleapis.com";
      };

      google_service_account.external_secrets = {
        inherit (self.gcloud) project;
        account_id = "external-secrets";
        depends_on = [
          "google_project_service.secretmanager"
        ];
      };
      google_service_account_iam_member.external_secrets_workload_identity = {
        service_account_id = /* terraform */ "\${google_service_account.external_secrets.name}";
        role = "roles/iam.workloadIdentityUser";
        member = "serviceAccount:${self.gcloud.project}.svc.id.goog[external-secrets/external-secrets]";
        depends_on = [
          "google_container_cluster.${self.gcloud.name}"
          "google_service_account.external_secrets"
        ];
      };
      google_project_iam_member.external_secrets_secret_accessor = {
        inherit (self.gcloud) project;
        role = "roles/secretmanager.secretAccessor";
        member = "serviceAccount:\${google_service_account.external_secrets.email}";
        depends_on = [
          "google_service_account.external_secrets"
        ];
      };

      google_secret_manager_secret = {
        tailscale_oauth_client_id = {
          inherit (self.gcloud) project;
          secret_id = "tailscale-oauth-client-id";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        tailscale_oauth_client_secret = {
          inherit (self.gcloud) project;
          secret_id = "tailscale-oauth-client-secret";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        better_auth_secret = {
          inherit (self.gcloud) project;
          secret_id = "better-auth-secret";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        openai_api_key = {
          inherit (self.gcloud) project;
          secret_id = "openai-api-key";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        redis_user = {
          inherit (self.gcloud) project;
          secret_id = "redis-user";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        redis_password = {
          inherit (self.gcloud) project;
          secret_id = "redis-password";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
      };
    };
  };
}
