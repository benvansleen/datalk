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
        celld_auth_secret = {
          inherit (self.gcloud) project;
          secret_id = "celld-auth-secret";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        internal_cell_secret = {
          inherit (self.gcloud) project;
          secret_id = "internal-cell-secret";
          replication.auto = { };
          depends_on = [
            "google_service_account.external_secrets"
          ];
        };
        internal_projection_secret = {
          inherit (self.gcloud) project;
          secret_id = "internal-projection-secret";
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
      };
    };
  };

  perSystem = { pkgs, lib, ... }: {
    apps.populate-prod-secrets = {
      type = "app";
      program = lib.getExe (
        pkgs.writers.writePython3Bin "populate-prod-secrets" { } /* python */ ''
          import shlex
          import subprocess
          import sys
          from pathlib import Path


          PROJECT = "${self.gcloud.project}"
          GCLOUD = "${lib.getExe pkgs.google-cloud-sdk}" # noqa
          SECRET_IDS = {
              "BETTER_AUTH_SECRET": "better-auth-secret",
              "INTERNAL_CELL_SECRET": "internal-cell-secret",
              "INTERNAL_PROJECTION_SECRET": "internal-projection-secret",
              "OPENAI_API_KEY": "openai-api-key",
              "TAILSCALE_OAUTH_CLIENT_ID": "tailscale-oauth-client-id",
              "TAILSCALE_OAUTH_CLIENT_SECRET": "tailscale-oauth-client-secret",
          }


          def parse_env(path: Path) -> dict[str, str]:
              values = {}
              for raw_line in path.read_text().splitlines():
                  line = raw_line.strip()
                  if not line or line.startswith("#"):
                      continue
                  if line.startswith("export "):
                      line = line[len("export "):].lstrip()
                  if "=" not in line:
                      continue

                  key, value = line.split("=", 1)
                  key = key.strip()
                  value = value.strip()

                  if value.startswith(("'", '"')):
                      try:
                          parsed = shlex.split(value, comments=False, posix=True)
                      except ValueError as error:
                          message = f"invalid value for {key} in {path}: {error}"
                          raise SystemExit(message) from error
                      values[key] = parsed[0] if parsed else ""
                  else:
                      values[key] = value
              return values


          def main() -> int:
              env_file = Path(sys.argv[1] if len(sys.argv) > 1 else ".env.prod.k8s")
              if not env_file.is_file():
                  print(f"missing {env_file}", file=sys.stderr)
                  return 1

              values = parse_env(env_file)
              missing = [key for key in SECRET_IDS if key not in values]
              if missing:
                  missing_keys = " ".join(missing)
                  print(
                      f"missing keys in {env_file}: {missing_keys}",
                      file=sys.stderr,
                  )
                  return 1

              for key, secret_id in SECRET_IDS.items():
                  print(f"adding Secret Manager version for {secret_id} from {key}")
                  subprocess.run(
                      [
                          GCLOUD,
                          "secrets",
                          "versions",
                          "add",
                          secret_id,
                          "--project",
                          PROJECT,
                          "--data-file=-",
                      ],
                      input=values[key].encode(),
                      check=True,
                  )

              return 0


          if __name__ == "__main__":
              raise SystemExit(main())
        ''
      );
    };
  };
}
