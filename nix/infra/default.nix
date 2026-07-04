{ inputs, self, ... }:

{
  imports = [ inputs.terranix.flakeModule ];

  flake-file.inputs = {
    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:

    let
      terraform =
        with pkgs;
        opentofu.withPlugins (
          plugins: with plugins; [
            # gcloud container clusters get-credentials datalk --zone us-east4-a
            hashicorp_google
            hashicorp_external
          ]
        );

      tfLifecycle =
        {
          init ? "",
          apply ? "",
          destroy ? "",
        }:
        /* sh */ ''
          case "$1" in
            init)
              ${init}
            ;;
            apply)
              ${apply}
            ;;
            destroy)
              ${destroy}
            ;;
          esac
        '';

      kubectl = lib.getExe pkgs.kubectl;
      nixidyDiff =
        env:
        tfLifecycle {
          apply = /* sh */ ''
            to_apply="${env}"

            diff_status=0
            found_manifests=0
            for manifest in "$to_apply"/*/*.yaml; do
              [ -e "$manifest" ] || continue
              case "$manifest" in
                "$to_apply"/apps/*)
                  continue
                ;;
              esac

              found_manifests=1

              if KUBECTL_EXTERNAL_DIFF=${
                lib.getExe self.packages.${system}.cleanKubectlDiff
              } ${kubectl} diff -f "$manifest"; then
                true
              else
                status=$?
                if [ "$status" -eq 1 ]; then
                  diff_status=1
                else
                  echo "kubectl diff failed for $manifest with exit code $status" >&2
                  exit "$status"
                fi
              fi
            done

            if [ "$found_manifests" -eq 0 ]; then
              echo "No manifests found under $to_apply" >&2
              exit 1
            fi

            if [ "$diff_status" -eq 0 ]; then
              echo "No changes to cluster"
            fi
          '';
        };
    in
    {
      terranix = {
        exportDevShells = false;
        terranixConfigurations = {
          production =
            let
              manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.default;
            in
            {
              modules = with self.modules.infra; [
                production
                { manifest = manifest.declarativePackage; }
              ];
              terraformWrapper = {
                package = terraform;
                prefixText = nixidyDiff manifest.environmentPackage;
              };
            };
          local =
            let
              manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.local;
            in
            {
              modules = with self.modules.infra; [
                k3d
                {
                  manifest = manifest.declarativePackage;
                }
              ];
              workdir = ".terraform/local";
              terraformWrapper = {
                package = terraform;
                prefixText = nixidyDiff manifest.environmentPackage;
              };
            };
        };
      };
    };

  flake.image-tag = img: builtins.substring 11 32 (toString img.outPath);
}
