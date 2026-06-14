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
        modules = [ self.modules.infra.k8s ];
      };
    in
    {
      apps = {
        tf-apply = {
          type = "app";
          program = toString (
            pkgs.writers.writeBash "apply" ''
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
            pkgs.writers.writeBash "destroy" ''
              [[ -e config.tf.json ]] && rm -f config.tf.json
              cp ${terraformConfiguration} config.tf.json \
              && ${lib.getExe terraform} init \
              && ${lib.getExe terraform} destroy
            ''
          );
        };
      };
    };
}
