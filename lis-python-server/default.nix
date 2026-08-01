{
  buildGoModule,
  go,
  lib,
  lisette,
  runCommand,
  ...
}:

let
  manifest = fromTOML (builtins.readFile ./lisette.toml);

  generatedGo =
    runCommand "lis-python-server-generated-go"
      {
        nativeBuildInputs = [
          go
        ];
      }
      /* sh */ ''
        export HOME="$TMPDIR"

        mkdir project
        cp -r ${./src} project/src
        cp ${./lisette.toml} project/lisette.toml
        chmod -R u+w project

        cd project
        ${lib.getExe lisette} emit

        mkdir "$out"
        cp -r target/. "$out/"
        rm -rf "$out/.lisette"
      '';
in
buildGoModule {
  inherit (manifest.project) version;
  pname = manifest.project.name;
  src = generatedGo;
  vendorHash = null;
  nativeBuildInputs = [ lisette ];
}
