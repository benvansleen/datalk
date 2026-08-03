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
  lisProject =
    runCommand "lis-python-server-emitted"
      {
        nativeBuildInputs = [ go ];
        outputHashMode = "recursive";
        outputHash = "sha256-KbHhYtjGolKQnHPCJJ3WIdzgAUUIow9O+SGYnxwKTzs=";
      }
      /* sh */ ''
        export HOME="$TMPDIR"
        export GOCACHE="$TMPDIR/go-cache"
        export GOMODCACHE="$TMPDIR/go-mod-cache"
        export GOTOOLCHAIN=local
        export GOWORK=off
        export GOSUMDB=off

        mkdir project
        cp -r ${./src} project/src
        cp ${./lisette.toml} project/lisette.toml
        chmod -R u+w project

        cd project
        ${lib.getExe lisette} emit

        mkdir -p "$out"
        cp -r target/. "$out/project/"
        rm -rf "$out/project/.lisette"
        cp -r "$GOMODCACHE/cache/download" "$out/go-modules"
      '';
in
buildGoModule {
  inherit (manifest.project) version;
  pname = manifest.project.name;
  src = "${lisProject}/project";
  proxyVendor = true;
  vendorHash = null;
  ldflags = [
    "-s"
    "-w"
  ];

  postConfigure = /* sh */ ''
    export GOPROXY="file://${lisProject}/go-modules,off"
    export GOSUMDB=off
    export GOTOOLCHAIN=local
    export GOWORK=off
    export GOFLAGS="-buildvcs=false $GOFLAGS"
  '';

  nativeBuildInputs = [ lisette ];
  meta.mainProgram = manifest.project.name;
}
