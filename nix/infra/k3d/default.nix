{ self, ... }:

{
  flake = {
    local-image-uri = img: "k3d-datalk-local-registry:5000/${img.imageName}:${self.image-tag img}";
    local-image-repo = "localhost:5001";
    local-image-push-uri = img: "${self.local-image-repo}/${img.imageName}:${self.image-tag img}";

    modules.infra.k3d =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        git = lib.getExe pkgs.git;
        kubectl = lib.getExe pkgs.kubectl;

        registriesConf = pkgs.writeText "registries.conf" /* toml */ ''
          unqualified-search-registries = ["docker.io"]

          [[registry]]
          location = "${self.local-image-repo}"
          insecure = true
        '';

        imgs = with self.packages.${system}; [
          datalk-image
          datalk-dev-image
          python-server-image
        ];
        imageKey = img: lib.replaceStrings [ "-" ] [ "_" ] img.imageName;
        pushImage = img: {
          name = "push_${imageKey img}";
          value = {
            triggers_replace = "${img}";
            input.uri = self.local-image-push-uri img;
            depends_on = [ "terraform_data.k3d_registry" ];
            provisioner.local-exec.command = /* sh */ ''
              uri="docker://''${self.input.uri}"

              containers_home="$(mktemp -d)"
              trap 'rm -rf "$containers_home"' EXIT

              mkdir -p "$containers_home/.config/containers"
              cp ${registriesConf} "$containers_home/.config/containers/registries.conf"

              echo "pushing $uri"
              HOME="$containers_home" XDG_CONFIG_HOME="$containers_home/.config" \
                ${img.copyTo}/bin/copy-to \
                  --dest-tls-verify=false \
                  --dest-no-creds \
                  --registries.d "$containers_home/.config/containers" \
                  "$uri"
            '';
          };
        };
        pushImages = builtins.listToAttrs (map pushImage imgs);
      in
      {
        options.manifest =
          with lib;
          mkOption {
            type = types.package;
          };

        imports = with self.modules.infra; [
          k3d-cluster
          k3d-secrets
        ];

        config = {
          resource.terraform_data = pushImages // {
            apply_local = {
              triggers_replace.manifest = toString config.manifest;
              provisioner.local-exec.command = /* sh */ ''
                repo_root="$(${git} rev-parse --show-toplevel)"
                cd "$repo_root"
                ${kubectl} config use-context k3d-${self.gcloud.name}-local
                ${config.manifest}/apply
              '';
              depends_on = [
                "terraform_data.k3d_cluster"
                "terraform_data.local_secrets"
              ]
              ++ map (img: "terraform_data.push_${imageKey img}") imgs;
            };
          };
        };
      };
  };
}
