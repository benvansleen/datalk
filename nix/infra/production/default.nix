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
        kubectl = lib.getExe pkgs.kubectl;

        registriesConf = pkgs.writeText "registries.conf" /* toml */ ''
          unqualified-search-registries = ["docker.io"]
        '';

        imgs = with self.packages.${system}; [
          datalk-image
          python-server-image
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
        options = with lib; {
          context = mkOption {
            type = types.str;
          };
          manifest = mkOption {
            type = types.package;
          };
          prepareContext = mkOption {
            type = types.str;
            default = "";
          };
        };

        imports = with self.modules.infra; [
          production-k8s
          production-secrets
        ];

        config = {
          resource.terraform_data = pushImages // {
            apply = {
              triggers_replace.manifest = toString config.manifest;
              provisioner.local-exec.command = /* sh */ ''
                ${config.prepareContext}
                ${kubectl} config use-context "${config.context}"
                ${config.manifest}/apply
              '';
              depends_on = [
                "google_container_cluster.${self.gcloud.name}"
                "terraform_data.propagate_secrets"
              ]
              ++ map (img: "terraform_data.push_${imageKey img}") imgs;
            };

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
