{ inputs, ... }:

{
  flake-file.inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem.treefmt =
    { pkgs, lib, ... }:
    {
      projectRootFile = "flake.nix";
      settings = {
        formatter = {
          lisfmt = {
            command = lib.getExe pkgs.bash;
            options = [
              "-euc"
              ''
                for file in "$@"; do
                  ${lib.getExe pkgs.lisette} format "$file"
                done
              ''
              "--"
            ];
            includes = [ "**/*.lis" ];
          };
          oxfmt = {
            command = lib.getExe (
              pkgs.callPackage ./_oxfmt.nix {
                inherit (lib) removePrefix;
                inherit (inputs.gitignore.lib) gitignoreSource;
              }
            );
            includes = [
              "**/*.css"
              "**/*.js"
              "**/*.ts"
              "**/*.svelte"
            ];
          };
        };
        global.excludes = [
          ".envrc"
          "*.png"
        ];
      };

      programs = {
        beautysh.enable = true;
        jsonfmt = {
          enable = true;
          excludes = [
            "*/tsconfig.json"
          ];
        };
        nixfmt.enable = true;
        shellcheck = {
          enable = true;
          excludes = [
            ".envrc.sample"
          ];
        };
        statix.enable = true;
        yamlfmt.enable = true;
      };

      # List of formatters available at https://github.com/numtide/treefmt-nix?tab=readme-ov-file#supported-programs
    };
}
