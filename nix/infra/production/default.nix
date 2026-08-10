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
        gcloud = lib.getExe pkgs.google-cloud-sdk;

        registriesConf = pkgs.writeText "registries.conf" /* toml */ ''
          unqualified-search-registries = ["docker.io"]
        '';

        imgs = with self.packages.${system}; [
          datalk-image
          celld-deploy-source-image
          lis-python-server-image
          lis-python-worker-image
        ];
        imageKey = img: lib.replaceStrings [ "-" ] [ "_" ] img.imageName;
        pushImage = img: {
          name = "push_${imageKey img}";
          value = {
            triggers_replace = "${img}";
            input.uri = self.image-uri img;
            depends_on = [ "google_artifact_registry_repository.${self.gcloud.name}" ];
            provisioner.local-exec.command = /* sh */ ''
              uri="docker://''${self.input.uri}"

              containers_home="$(mktemp -d)"
              trap 'rm -rf "$containers_home"' EXIT

              mkdir -p "$containers_home/.config/containers"
              cp ${registriesConf} "$containers_home/.config/containers/registries.conf"

              echo "pushing $uri"
              token="$(${gcloud} auth print-access-token)"
              HOME="$containers_home" XDG_CONFIG_HOME="$containers_home/.config" \
                ${img.copyTo}/bin/copy-to \
                  --dest-creds "oauth2accesstoken:$token" \
                  "$uri"
            '';
          };
        };
        pushImages = builtins.listToAttrs (map pushImage imgs);
      in
      {
        imports = with self.modules.infra; [
          production-k8s
          production-secrets
          production-datasets
        ];

        config = {
          resource.terraform_data = pushImages // {
            propagate_secrets =
              let
                secretsFile = "../../.env.prod.k8s";
              in
              {
                input.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                triggers_replace.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                depends_on = map (name: "google_secret_manager_secret.${name}") (
                  builtins.attrNames config.resource.google_secret_manager_secret
                );
                provisioner.local-exec.command = /* sh */ ''
                  ${self.apps.${system}.populate-prod-secrets.program} "${secretsFile}"
                '';
              };
          };
        };
      };
  };
}
