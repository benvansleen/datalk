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
      self',
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
        {
          env,
          context,
          prepareContext ? "",
          skipIfUnavailable ? false,
        }:
        tfLifecycle {
          apply = /* sh */ ''
            to_apply="${env}"
            kubectl_context="${context}"
            skip_nixidy_diff=0

            if ! ${kubectl} config get-contexts "$kubectl_context" >/dev/null 2>&1; then
              ${
                if skipIfUnavailable then
                  /* sh */ ''
                    echo "Kubernetes context $kubectl_context is unavailable; skipping live nixidy diff"
                    skip_nixidy_diff=1
                  ''
                else
                  /* sh */ ''
                    echo "Kubernetes context $kubectl_context is unavailable" >&2
                    exit 1
                  ''
              }
            fi

            ${prepareContext}

            if [ "$skip_nixidy_diff" -eq 0 ]; then
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

              if KUBECTL_EXTERNAL_DIFF=${lib.getExe self'.packages.cleanKubectlDiff} ${kubectl} --context "$kubectl_context" diff -f "$manifest"; then
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
              context = "gke_${self.gcloud.project}_${self.gcloud.zone}_${self.gcloud.name}";
              manifest = self'.legacyPackages.nixidyEnvs.${system}.default;
              prepareContext = /* sh */ ''
                ${lib.getExe pkgs.google-cloud-sdk} container clusters get-credentials \
                  ${self.gcloud.name} \
                  --zone ${self.gcloud.zone} \
                  --project ${self.gcloud.project} >/dev/null 2>&1 || true
              '';
            in
            {
              workdir = ".terraform/production";
              modules = with self.modules.infra; [
                production
                {
                  inherit context prepareContext;
                  manifest = manifest.declarativePackage;
                }
              ];
              terraformWrapper = {
                package = terraform;
                prefixText = nixidyDiff {
                  inherit context prepareContext;
                  env = manifest.environmentPackage;
                  skipIfUnavailable = true;
                };
              };
            };
          local =
            let
              context = "k3d-${self.gcloud.name}-local";
              manifest = self'.legacyPackages.nixidyEnvs.${system}.local;
            in
            {
              modules = with self.modules.infra; [
                k3d
                {
                  inherit context;
                  manifest = manifest.declarativePackage;
                }
              ];
              workdir = ".terraform/local";
              terraformWrapper = {
                package = terraform;
                prefixText = nixidyDiff {
                  inherit context;
                  env = manifest.environmentPackage;
                };
              };
            };
        };
      };
    };

  flake.image-tag = img: builtins.substring 11 32 (toString img.outPath);
}
