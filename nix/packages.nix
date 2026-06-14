{ inputs, ... }:

{
  flake-file.inputs = {
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  perSystem =
    { pkgs, ... }:
    {
      packages = {
        ui = pkgs.callPackage ../ui inputs;
        python-server = pkgs.callPackage ../python-server inputs;
      };
    };
}
