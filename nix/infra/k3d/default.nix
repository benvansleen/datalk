{ self, ... }:

{
  flake = {
    local-image-uri = img: "k3d-datalk-local-registry:5000/${img.imageName}:${self.image-tag img}";
    local-image-push-uri = img: "localhost:5001/${img.imageName}:${self.image-tag img}";

    modules.infra.k3d =
      {
        pkgs,
        lib,
        ...
      }:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        git = lib.getExe pkgs.git;
        kubectl = lib.getExe pkgs.kubectl;
        skopeo = lib.getExe pkgs.skopeo;
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
            input = {
              uri = self.local-image-push-uri img;
              exists = "\${data.external.image_exists_${imageKey img}.result.exists}";
            };
            depends_on = [ "terraform_data.k3d_registry" ];
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
        manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.local.declarativePackage;
      in
      {
        imports = with self.modules.infra; [
          k3d-cluster
          k3d-secrets
        ];

        resource.terraform_data = pushImages // {
          apply_local = {
            triggers_replace.manifest = toString manifest;
            provisioner.local-exec.command = /* sh */ ''
              repo_root="$(${git} rev-parse --show-toplevel)"
              cd "$repo_root"
              ${kubectl} config use-context k3d-${self.gcloud.name}-local
              ${lib.getExe self.packages.${system}.nixidy} apply .#local
            '';
            depends_on = [
              "terraform_data.k3d_cluster"
              "terraform_data.local_secrets"
            ]
            ++ map (img: "terraform_data.push_${imageKey img}") imgs;
          };
        };

        data.external = builtins.listToAttrs (
          map (img: {
            name = "image_exists_${imageKey img}";
            value = {
              program = [
                (lib.getExe pkgs.bash)
                "-c"
                /* sh */ ''
                  if ${skopeo} inspect --tls-verify=false "docker://${self.local-image-push-uri img}" >/dev/null 2>&1;
                  then
                    printf '{"exists":"true"}\n'
                  else
                    printf '{"exists":"false"}\n'
                  fi
                ''
              ];
              depends_on = [ "terraform_data.k3d_registry" ];
            };
          }) imgs
        );
      };
  };
}
