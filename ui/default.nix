{
  buildNpmPackage,
  esbuild,
  gitignore,
  importNpmLock,
  lib,
  nodejs_22,
  writeShellApplication,
  ...
}:

let
  inherit (gitignore.lib) gitignoreSource;
  nodejs = nodejs_22;
  root = ./.;
  packageJSON = lib.importJSON (root + "/package.json");
  commonNpmPackageAttrs = {
    inherit nodejs;
    inherit (packageJSON) version;
    inherit (importNpmLock) npmConfigHook;
    src = gitignoreSource root;
    npmPackFlags = [ ];
    npmDeps = importNpmLock { npmRoot = root; };
    nativeBuildInputs = [ esbuild ];
  };
  bundleMigrate = outfile: /* sh */ ''
    esbuild scripts/migrate.ts \
      --bundle \
      --platform=node \
      --format=esm \
      --target=node22 \
      --outfile=${outfile}
  '';
  site = buildNpmPackage (
    commonNpmPackageAttrs
    // {
      pname = packageJSON.name;

      postBuild = bundleMigrate "migrate.mjs";

      installPhase = /* sh */ ''
        mkdir -p $out/
        cp -r build/* $out/
        cp migrate.mjs $out/migrate.mjs
        cp -r drizzle $out/drizzle
      '';
    }
  );

  migrate = writeShellApplication {
    name = "migrate";
    text = /* sh */ ''
      cd ${site}
      exec ${lib.getExe nodejs} ./migrate.mjs
    '';
  };
  devRoot = buildNpmPackage (
    commonNpmPackageAttrs
    // {
      pname = "${packageJSON.name}-dev-root";
      dontNpmBuild = true;

      installPhase = /* sh */ ''
        runHook preInstall

        mkdir -p $out/app
        cp package.json package-lock.json $out/app/
        cp svelte.config.js vite.config.ts tsconfig.json drizzle.config.ts $out/app/
        cp -r node_modules scripts drizzle static $out/app/
        ${bundleMigrate "$out/app/migrate.mjs"}

        runHook postInstall
      '';
    }
  );
in
writeShellApplication {
  inherit (packageJSON) name;
  text = /* sh */ ''
    export ORIGIN="''${ORIGIN:-http://localhost:3000}"
    export PORT="''${PORT:-3000}"
    ${lib.getExe nodejs} ${site}
  '';
  passthru = {
    inherit site migrate devRoot;
  };
}
