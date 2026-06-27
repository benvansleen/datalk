{ inputs, self, ... }:

{
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
      terraform = pkgs.opentofu;
      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = with self.modules.infra; [
          k8s
          providers
          secrets
        ];
      };
      localTerraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = with self.modules.infra; [
          k3d
        ];
      };
    in
    {
      apps = {
        tf-apply = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "apply" /* sh */ ''
              [[ -e config.tf.json ]] && rm -f config.tf.json
              cp ${terraformConfiguration} config.tf.json \
              && ${lib.getExe terraform} init \
              && ${lib.getExe terraform} apply
            ''
          );
        };
        tf-destroy = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "destroy" /* sh */ ''
              [[ -e config.tf.json ]] && rm -f config.tf.json
              cp ${terraformConfiguration} config.tf.json \
              && ${lib.getExe terraform} init \
              && ${lib.getExe terraform} destroy
            ''
          );
        };

        tf-apply-local = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "apply-local" /* sh */ ''
              [[ -e .terraform/local/config.tf.json ]] && rm -f .terraform/local/config.tf.json
              mkdir -p .terraform/local
              cp ${localTerraformConfiguration} .terraform/local/config.tf.json \
              && ${lib.getExe terraform} -chdir=.terraform/local init \
              && ${lib.getExe terraform} -chdir=.terraform/local apply
            ''
          );
        };
        tf-destroy-local = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "apply-local" /* sh */ ''
              [[ -e .terraform/local/config.tf.json ]] && rm -f .terraform/local/config.tf.json
              mkdir -p .terraform/local
              cp ${localTerraformConfiguration} .terraform/local/config.tf.json \
              && ${lib.getExe terraform} -chdir=.terraform/local init \
              && ${lib.getExe terraform} -chdir=.terraform/local destroy
            ''
          );
        };

        populate-prod-secrets = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "populate-prod-secrets" /* sh */ ''
              set -euo pipefail

              env_file="''${1:-.env.prod.k8s}"

              if [ ! -f "$env_file" ]; then
                echo "missing $env_file" >&2
                exit 1
              fi

              declare -A secret_ids=(
                [BETTER_AUTH_SECRET]=better-auth-secret
                [OPENAI_API_KEY]=openai-api-key
                [REDIS_USER]=redis-user
                [REDIS_PASSWORD]=redis-password
                [TAILSCALE_OAUTH_CLIENT_ID]=tailscale-oauth-client-id
                [TAILSCALE_OAUTH_CLIENT_SECRET]=tailscale-oauth-client-secret
              )
              ordered_keys=(
                BETTER_AUTH_SECRET
                OPENAI_API_KEY
                REDIS_USER
                REDIS_PASSWORD
                TAILSCALE_OAUTH_CLIENT_ID
                TAILSCALE_OAUTH_CLIENT_SECRET
              )

              declare -A values=()
              while IFS= read -r line || [ -n "$line" ]; do
                line="''${line%$'\r'}"
                if [[ -z "$line" || "$line" == \#* ]]; then
                  continue
                fi
                if [[ "$line" == export\ * ]]; then
                  line="''${line#export }"
                fi
                if [[ "$line" != *=* ]]; then
                  continue
                fi

                key="''${line%%=*}"
                value="''${line#*=}"
                key="''${key#"''${key%%[![:space:]]*}"}"
                key="''${key%"''${key##*[![:space:]]}"}"
                if [[ "$value" == \"*\" && "$value" == *\" ]]; then
                  value="''${value:1:''${#value}-2}"
                elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
                  value="''${value:1:''${#value}-2}"
                fi

                values["$key"]="$value"
              done < "$env_file"

              missing=()
              for key in "''${ordered_keys[@]}"; do
                if [[ ! -v "values[$key]" ]]; then
                  missing+=("$key")
                fi
              done
              if [ "''${#missing[@]}" -gt 0 ]; then
                echo "missing keys in $env_file: ''${missing[*]}" >&2
                exit 1
              fi

              for key in "''${ordered_keys[@]}"; do
                secret_id="''${secret_ids[$key]}"
                echo "adding Secret Manager version for $secret_id from $key"
                printf %s "''${values[$key]}" \
                  | ${pkgs.google-cloud-sdk}/bin/gcloud secrets versions add "$secret_id" \
                    --project ${self.gcloud.project} \
                    --data-file=-
              done
            ''
          );
        };
      };
    };
}
