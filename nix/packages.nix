{ inputs, ... }:

{
  flake-file.inputs = {
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  perSystem =
    {
      inputs',
      self',
      pkgs,
      ...
    }:
    {
      packages = {
        ui = pkgs.callPackage ../ui inputs;
        python-server = pkgs.callPackage ../python-server inputs;

        datalk-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "datalk";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "datalk-image-root";
            paths = [
              self'.packages.ui
              self'.packages.ui.site
            ];
            pathsToLink = [ "/" ];
          };
          config = {
            Cmd = [ "/bin/ui" ];
          };
        };
      };
    };
}
