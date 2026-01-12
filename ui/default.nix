{
  lib,
  pkgs,
  buildNpmPackage,
  importNpmLock,
  writeShellApplication,
  gitignore,
  ...
}:

let
  inherit (gitignore.lib) gitignoreSource;
  nodejs = pkgs.nodejs_22;
  root = ./.;
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
    export ORIGIN=http://localhost:3000
    ${lib.getExe nodejs} ${site}
  '';
  passthru = site;
}
