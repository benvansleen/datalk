{
  projectRootFile = "flake.nix";
  settings.global.excludes = [
    ".envrc"
    "*.sops*"
    "*.png"
  ];

  programs = {
    nixfmt.enable = true;
    statix.enable = true;
    beautysh.enable = true;
    shellcheck.enable = true;
    jsonfmt.enable = true;
    yamlfmt.enable = true;
    prettier.enable = true;
  };

  # List of formatters available at https://github.com/numtide/treefmt-nix?tab=readme-ov-file#supported-programs
}
