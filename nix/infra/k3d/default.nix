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
      {
        imports = with self.modules.infra; [
          k3d-cluster
          k3d-secrets
        ];

        resource.terraform_data =
          let
            inherit (pkgs.stdenv.hostPlatform) system;
            git = lib.getExe pkgs.git;
            kubectl = lib.getExe pkgs.kubectl;
            imgs = with self.packages.${system}; [
              datalk-image
              datalk-dev-image
              python-server-image
            ];
            pushImage = img: {
              name = "push_${img.imageName}";
              value = {
                triggers_replace = "${img}";
                input = self.local-image-push-uri img;
                depends_on = [ "terraform_data.k3d_registry" ];
                provisioner.local-exec.command = /* sh */ ''
                  uri="docker://''${self.input}"
                  echo "pushing $uri"
                  ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$uri"
                '';
              };
            };
            pushImages = builtins.listToAttrs (map pushImage imgs);
            manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.local.declarativePackage;
          in
          pushImages
          // {
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
              ++ map (img: "terraform_data.push_${img.imageName}") imgs;
            };
          };
      };
  };
}
