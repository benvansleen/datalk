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
      terraform =
        with pkgs;
        lib.getExe (
          opentofu.withPlugins (
            plugins: with plugins; [
              hashicorp_null
              hashicorp_google
            ]
          )
        );
      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = with self.modules.infra; [
          application
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
      mkTerraformApp =
        {
          name,
          configuration,
          command,
          chdir ? null,
        }:
        let
          configPath = if chdir == null then "config.tf.json" else "${chdir}/config.tf.json";
          terraformArgs = lib.optionalString (chdir != null) "-chdir=${chdir} ";
        in
        {
          type = "app";
          program = toString (
            pkgs.writers.writeBash name /* sh */ ''
              ${lib.optionalString (chdir != null) "mkdir -p ${chdir}"}
              [[ -e ${configPath} ]] && rm -f ${configPath}
              cp ${configuration} ${configPath} \
                && ${terraform} ${terraformArgs}init \
                && ${terraform} ${terraformArgs}${command} -parallelism=24 $@
            ''
          );
        };
    in
    {
      apps = {
        tf-apply = mkTerraformApp {
          name = "tf-apply";
          configuration = terraformConfiguration;
          command = "apply";
        };
        tf-destroy = mkTerraformApp {
          name = "tf-destroy";
          configuration = terraformConfiguration;
          command = "destroy";
        };

        tf-apply-local = mkTerraformApp {
          name = "tf-apply-local";
          configuration = localTerraformConfiguration;
          command = "apply";
          chdir = ".terraform/local";
        };
        tf-destroy-local = mkTerraformApp {
          name = "tf-destroy-local";
          configuration = localTerraformConfiguration;
          command = "destroy";
          chdir = ".terraform/local";
        };

        populate-prod-secrets = {
          type = "app";
          program = lib.getExe (
            pkgs.writers.writePython3Bin "populate-prod-secrets" { } /* python */ ''
              import shlex
              import subprocess
              import sys
              from pathlib import Path


              PROJECT = "${self.gcloud.project}"
              GCLOUD = "${lib.getExe pkgs.google-cloud-sdk}" # noqa
              SECRET_IDS = {
                  "BETTER_AUTH_SECRET": "better-auth-secret",
                  "OPENAI_API_KEY": "openai-api-key",
                  "REDIS_USER": "redis-user",
                  "REDIS_PASSWORD": "redis-password",
                  "TAILSCALE_OAUTH_CLIENT_ID": "tailscale-oauth-client-id",
                  "TAILSCALE_OAUTH_CLIENT_SECRET": "tailscale-oauth-client-secret",
              }


              def parse_env(path: Path) -> dict[str, str]:
                  values = {}
                  for raw_line in path.read_text().splitlines():
                      line = raw_line.strip()
                      if not line or line.startswith("#"):
                          continue
                      if line.startswith("export "):
                          line = line[len("export "):].lstrip()
                      if "=" not in line:
                          continue

                      key, value = line.split("=", 1)
                      key = key.strip()
                      value = value.strip()

                      if value.startswith(("'", '"')):
                          try:
                              parsed = shlex.split(value, comments=False, posix=True)
                          except ValueError as error:
                              message = f"invalid value for {key} in {path}: {error}"
                              raise SystemExit(message) from error
                          values[key] = parsed[0] if parsed else ""
                      else:
                          values[key] = value
                  return values


              def main() -> int:
                  env_file = Path(sys.argv[1] if len(sys.argv) > 1 else ".env.prod.k8s")
                  if not env_file.is_file():
                      print(f"missing {env_file}", file=sys.stderr)
                      return 1

                  values = parse_env(env_file)
                  missing = [key for key in SECRET_IDS if key not in values]
                  if missing:
                      missing_keys = " ".join(missing)
                      print(
                          f"missing keys in {env_file}: {missing_keys}",
                          file=sys.stderr,
                      )
                      return 1

                  for key, secret_id in SECRET_IDS.items():
                      print(f"adding Secret Manager version for {secret_id} from {key}")
                      subprocess.run(
                          [
                              GCLOUD,
                              "secrets",
                              "versions",
                              "add",
                              secret_id,
                              "--project",
                              PROJECT,
                              "--data-file=-",
                          ],
                          input=values[key].encode(),
                          check=True,
                      )

                  return 0


              if __name__ == "__main__":
                  raise SystemExit(main())
            ''
          );
        };
      };
    };

  flake.image-tag = img: builtins.substring 11 32 (toString img.outPath);
}
