{
  buildNpmPackage,
  gitignoreSource,
  importNpmLock,
  removePrefix,
  nodejs,
  writeShellApplication,

}:

let
  root = gitignoreSource ../../ui;
  src = builtins.path {
    name = "datalk-oxfmt-runtime-src";
    path = root;
    filter =
      path: _type:
      let
        rel = removePrefix "${toString root}/" (toString path);
      in
      builtins.elem rel [
        "package.json"
        "package-lock.json"
        ".oxfmt.config.ts"
      ];
  };
  runtime = buildNpmPackage {
    pname = "datalk-oxfmt-runtime";
    version = "0.1.0";

    inherit src;
    inherit (importNpmLock) npmConfigHook;
    npmDeps = importNpmLock { npmRoot = src; };
    dontNpmBuild = true;

    installPhase = /* sh */ ''
      runHook preInstall

      mkdir -p $out
      cp -r node_modules $out/node_modules
      cp .oxfmt.config.ts $out/.oxfmt.config.ts

      runHook postInstall
    '';
  };
in
writeShellApplication {
  name = "oxfmt";
  runtimeInputs = [ nodejs ];
  text = /* sh */ ''
    exec ${runtime}/node_modules/.bin/oxfmt -c ${runtime}/.oxfmt.config.ts "$@"
  '';
}
