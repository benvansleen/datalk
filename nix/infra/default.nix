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
      };
    };
}
