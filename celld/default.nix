{
  buildNpmPackage,
  gitignore,
  importNpmLock,
  lib,
  nodejs_22,
  ...
}:

let
  inherit (gitignore.lib) gitignoreSource;
  root = ./.;
  packageJSON = lib.importJSON (root + "/package.json");
  deploySource = buildNpmPackage {
    pname = "${packageJSON.name}-deploy-source";
    inherit (packageJSON) version;
    src = gitignoreSource root;
    nodejs = nodejs_22;
    inherit (importNpmLock) npmConfigHook;
    npmDeps = importNpmLock { npmRoot = root; };
    dontNpmBuild = true;
    doCheck = true;

    checkPhase = ''
      npm run check
      npm test
    '';

    installPhase = ''
      mkdir -p $out/app
      node_modules/.bin/esbuild src/index.ts \
        --bundle \
        --format=esm \
        --platform=browser \
        --target=es2024 \
        --conditions=workerd,worker,browser \
        --external:node:* \
        --external:cloudflare:* \
        --outfile=$out/app/index.js
      cp wrangler.deploy.jsonc $out/app/wrangler.jsonc
      install -Dm755 node_modules/@esbuild/*/bin/esbuild $out/bin/esbuild
    '';
  };
in
buildNpmPackage {
  pname = "${packageJSON.name}-dev-root";
  inherit (packageJSON) version;
  src = gitignoreSource root;
  nodejs = nodejs_22;
  inherit (importNpmLock) npmConfigHook;
  npmDeps = importNpmLock { npmRoot = root; };
  dontNpmBuild = true;

  installPhase = ''
    mkdir -p $out/app
    cp package.json package-lock.json wrangler.jsonc tsconfig.json $out/app/
    cp -r node_modules $out/app/
  '';
  passthru = { inherit deploySource; };
}
