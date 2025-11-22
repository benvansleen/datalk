{
  lib,
  nodejs_22,
  buildNpmPackage,
  importNpmLock,
  writeShellApplication,
  gitignore,
  ...
}:

let
  inherit (gitignore.lib) gitignoreSource;
  nodejs = nodejs_22;
  root = ../ui;
  packageJSON = lib.importJSON (root + "/package.json");
  site = buildNpmPackage {
    inherit nodejs;
    inherit (packageJSON) version;
    inherit (importNpmLock) npmConfigHook;
    pname = packageJSON.name;
    src = gitignoreSource root;
    npmPackFlags = [ ];
    npmDeps = importNpmLock { npmRoot = root; };
    installPhase = ''
      mkdir -p $out/
      cp -r build/* $out/
    '';
  };
in
writeShellApplication {
  inherit (packageJSON) name;
  text = ''
     ${lib.getExe nodejs} ${site}
  '';
}
