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
    prettier = {
      enable = false;
      # includes = [
      #   ".ts"
      #   ".js"
      #   ".svelte"
      # ];
      settings = {
        parser = "typescript";
        # plugins = [ "@prettier/plugin-svelte" ];
        # overrides = [
        #   { files = "*.svelte"; options = { parser = "svelte"; }; }
        # ];
      };
    };
  };

  # List of formatters available at https://github.com/numtide/treefmt-nix?tab=readme-ov-file#supported-programs
}
