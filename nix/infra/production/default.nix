{ self, ... }:

{
  flake = {
    image-uri =
      let
        inherit (self.gcloud) project region name;
      in
      img: "${region}-docker.pkg.dev/${project}/${name}/${img.imageName}:${self.image-tag img}";

    modules.infra.production =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = with self.modules.infra; [
          production-k8s
          production-secrets
        ];

        resource.terraform_data =
          let
            inherit (pkgs.stdenv.hostPlatform) system;
            git = lib.getExe pkgs.git;
            gcloud = lib.getExe pkgs.google-cloud-sdk;
            kubectl = lib.getExe pkgs.kubectl;
            nixidy = lib.getExe self.packages.${system}.nixidy;
            imgs = with self.packages.${system}; [
              datalk-image
              python-server-image
            ];
            pushImage = img: {
              name = "push_${img.imageName}";
              value = {
                triggers_replace = "${img}";
                input = self.image-uri img;
                depends_on = [ "google_artifact_registry_repository.${self.gcloud.name}" ];
                provisioner.local-exec.command = /* sh */ ''
                  uri="docker://''${self.input}"
                  echo "pushing $uri"
                  ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$uri"
                '';
              };
            };
            pushImages = builtins.listToAttrs (map pushImage imgs);
            manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.default.declarativePackage;
          in
          {

            apply = {
              triggers_replace.manifest = toString manifest;
              provisioner.local-exec.command = /* sh */ ''
                repo_root="$(${git} rev-parse --show-toplevel)"
                cd "$repo_root"
                ${gcloud} container clusters \
                  get-credentials ${self.gcloud.name} \
                  --zone ${self.gcloud.zone}
                ${kubectl} config use-context gke_${self.gcloud.project}_${self.gcloud.zone}_${self.gcloud.name}
                ${nixidy} apply .#default
              '';
              depends_on = [
                "google_container_cluster.${self.gcloud.name}"
                "terraform_data.propagate_secrets"
              ]
              ++ map (img: "terraform_data.push_${img.imageName}") imgs;
            };

            propagate_secrets =
              let
                secretsFile = "./.env.prod.k8s";
              in
              {
                input.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                triggers_replace.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                depends_on = map (name: "google_secret_manager_secret.${name}") (
                  builtins.attrNames config.resource.google_secret_manager_secret
                );
                provisioner.local-exec.command = /* sh */ ''
                  ${self.apps.${system}.populate-prod-secrets.program}
                '';
              };

          }
          // pushImages;
      };
  };
}
