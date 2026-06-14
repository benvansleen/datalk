{ inputs, ... }:

{
  imports = [
    inputs.flake-file.flakeModules.dendritic
  ];

  flake-file = {
    nixConfig = {
      extra-substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
      flake-file.url = "github:vic/flake-file";

      secrets = {
        url = "git+ssh://git@github.com/benvansleen/datalk-secrets.git";
        # url = "path:/home/ben/Code/datalk/secrets";
        inputs = {
          nixpkgs.follows = "nixpkgs";
        };
      };
    };
    outputs = /* nix */ "inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix)";
  };
}
