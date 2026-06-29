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
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        git = lib.getExe pkgs.git;
        gcloud = lib.getExe pkgs.google-cloud-sdk;
        kubectl = lib.getExe pkgs.kubectl;
        nixidy = lib.getExe self.packages.${system}.nixidy;
        skopeo = lib.getExe pkgs.skopeo;
        imgs = with self.packages.${system}; [
          datalk-image
          python-server-image
        ];
        imageKey = img: lib.replaceStrings [ "-" ] [ "_" ] img.imageName;
        pushImage = img: {
          name = "push_${imageKey img}";
          value = {
            triggers_replace = "${img}";
            input = {
              uri = self.image-uri img;
              exists = "\${data.external.image_exists_${imageKey img}.result.exists}";
            };
            depends_on = [ "google_artifact_registry_repository.${self.gcloud.name}" ];
            provisioner.local-exec.command = /* sh */ ''
              uri="docker://''${self.input.uri}"
              if [ "''${self.input.exists}" = true ]; then
                echo "image already present: $uri"
              else
                echo "pushing $uri"
                ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$uri"
              fi
            '';
          };
        };
        pushImages = builtins.listToAttrs (map pushImage imgs);
        manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.default.declarativePackage;
      in
      {
        imports = with self.modules.infra; [
          production-k8s
          production-secrets
        ];

        resource.terraform_data = {

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
            ++ map (img: "terraform_data.push_${imageKey img}") imgs;
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

        data.external = builtins.listToAttrs (
          map (img: {
            name = "image_exists_${imageKey img}";
            value = {
              program = [
                (lib.getExe pkgs.bash)
                "-c"
                /* sh */ ''
                  if ${skopeo} inspect "docker://${self.image-uri img}" >/dev/null 2>&1;
                  then
                    printf '{"exists":"true"}\n'
                  else
                    printf '{"exists":"false"}\n'
                  fi
                ''
              ];
              depends_on = [ "google_artifact_registry_repository.${self.gcloud.name}" ];
            };
          }) imgs
        );
      };
  };
}
