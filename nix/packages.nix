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
            paths = with self'.packages; [
              ui
              ui.site
              ui.migrate
            ];
            pathsToLink = [ "/" ];
          };
          config.Cmd = [ "/bin/ui" ];
        };

        python-server-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "python-server";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "python-server-image-root";
            paths = with self'.packages; [ python-server ];
          };
          config.Cmd = [ "/bin/server" ];
        };
      };
    };
}
