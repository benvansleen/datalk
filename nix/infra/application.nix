{ self, ... }:

{
  flake = {
    image-uri =
      let
        inherit (self.gcloud) project region name;
      in
      img: "${region}-docker.pkg.dev/${project}/${name}/${img.imageName}:${self.image-tag img}";

    modules.infra.application =
      {
        pkgs,
        lib,
        ...
      }:
      {
        terraform.required_providers.null = {
          source = "hashicorp/null";
          version = "~> 3.2";
        };

        resource.null_resource =
          let
            inherit (pkgs.stdenv.hostPlatform) system;
          in
          {

            apply = {
              triggers.nixidy_env = "${self.legacyPackages.${system}.nixidyEnvs.${system}.default.declarativePackage
              }";
              depends_on = [
                "google_container_cluster.datalk"
                "null_resource.propagate_secrets"
                "null_resource.push_images"
              ];
              provisioner.local-exec.command = /* sh */ ''
                repo_root="$(${lib.getExe pkgs.git} rev-parse --show-toplevel)"
                cd "$repo_root"
                ${lib.getExe pkgs.google-cloud-sdk} container clusters \
                  get-credentials ${self.gcloud.name} \
                  --zone ${self.gcloud.zone}
                ${lib.getExe pkgs.kubectl} config use-context gke_${self.gcloud.project}_${self.gcloud.zone}_${self.gcloud.name}
                ${lib.getExe self.packages.${system}.nixidy} apply .#default
              '';
            };

            push_images =
              let
                imgs = with self.packages.${system}; [
                  datalk-image
                  python-server-image
                ];
              in
              {
                triggers = builtins.listToAttrs (
                  map (img: {
                    name = img.imageName;
                    value = "${img}";
                  }) imgs
                );
                depends_on = [ "google_artifact_registry_repository.datalk" ];
                provisioner.local-exec.command = lib.concatMapStringsSep "\n\n" (img: /* sh */ ''
                  uri="docker://${self.image-uri img}"
                  echo "pushing $uri"
                  ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$uri"
                '') imgs;
              };

            propagate_secrets =
              let
                secretsFile = "./.env.prod.k8s";
              in
              {
                triggers.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                ## TODO: extract programmatically
                depends_on = [
                  "google_secret_manager_secret.tailscale_oauth_client_id"
                  "google_secret_manager_secret.tailscale_oauth_client_secret"
                  "google_secret_manager_secret.better_auth_secret"
                  "google_secret_manager_secret.openai_api_key"
                  "google_secret_manager_secret.redis_user"
                  "google_secret_manager_secret.redis_password"
                ];
                provisioner.local-exec.command = /* sh */ ''
                  ${self.apps.${system}.populate-prod-secrets.program}
                '';
              };
          };
      };
  };
}
