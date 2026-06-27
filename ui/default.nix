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
    nativeBuildInputs = with pkgs; [ esbuild ];

    postBuild = /* sh */ ''
      esbuild scripts/migrate.ts \
        --bundle \
        --platform=node \
        --format=esm \
        --target=node22 \
        --outfile=migrate.mjs
    '';

    installPhase = /* sh */ ''
      mkdir -p $out/
      cp -r build/* $out/
      cp migrate.mjs $out/migrate.mjs
      cp -r drizzle $out/drizzle
    '';
  };

  migrate = writeShellApplication {
    name = "migrate";
    text = /* sh */ ''
      cd ${site}
      exec ${lib.getExe nodejs} ./migrate.mjs
    '';
  };
in
writeShellApplication {
  inherit (packageJSON) name;
  text = /* sh */ ''
    export ORIGIN="''${ORIGIN:-http://localhost:3000}"
    export PORT="''${PORT:-3000}"
    ${lib.getExe nodejs} ${site}
  '';
  passthru = {
    inherit site migrate;
  };
}
