{ inputs, ... }:

{
  flake-file.inputs = {
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  perSystem =
    { self', system, ... }:
    {
      checks = {
        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ../.;
          hooks = {
            check-added-large-files.enable = true;
            check-merge-conflicts.enable = true;
            detect-private-keys = {
              enable = true;
              excludes = [
                "nix/kubernetes/_generated/external-secrets.nix"
              ];
            };
            deadnix = {
              enable = true;
              excludes = [
                "nix/kubernetes/_generated/"
              ];
            };
            end-of-file-fixer = {
              enable = true;
              excludes = [ ".svg" ];
            };
            flake-checker.enable = true;
            oxlint.enable = true;
            ripsecrets.enable = true;
            statix.enable = true;
            treefmt = {
              enable = true;
              packageOverrides.treefmt = self'.formatter;
            };
            typos = {
              enable = true;
              excludes = [
                "nix/kubernetes/_generated/"
                ".ipynb"
              ];
              settings = {
                diff = false;
                ignored-words = [
                ];
              };
            };
          };
        };
      };
    };
}
