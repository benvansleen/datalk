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

  initialRequires =
    let
      deps = manifest.dependencies.go or { };
      pinVersion = pin: if builtins.isString pin then pin else pin.version;
      lines = lib.mapAttrsToList (module: pin: "\t${module} ${pinVersion pin}") deps;
    in
    lib.concatStringsSep "\n" (
      lines ++ [ "\tgithub.com/ivov/lisette/prelude v${lib.getVersion lisette}" ]
    );

  goModules =
    runCommand "lis-python-server-go-modules"
      {
        nativeBuildInputs = [ go ];
        outputHashMode = "recursive";
        outputHash = "sha256-5YBiofQTwU8r5IwjoCYEz0YsfS/+o6pWGZeG3l43ZBQ=";
      }
      /* sh */ ''
        export HOME="$TMPDIR"
        export GOCACHE="$TMPDIR/go-cache"
        export GOMODCACHE="$TMPDIR/go-mod-cache"
        export GOTOOLCHAIN=local
        export GOWORK=off
        export GOSUMDB=off

        # Pre-tidy graph: versions pinned in lisette.toml + prelude. Needed by
        # the bindgen typedef pass that runs before `go mod tidy`.
        mkdir deps-initial
        cat > deps-initial/go.mod <<EOF
        module lis-python-server

        go 1.25

        require (
        ${initialRequires}
        )
        EOF
        (cd deps-initial && go mod download all)

        # Final tidy'd graph: needed by `go mod tidy` and the Go build.
        mkdir deps-final
        cp ${./go.mod} deps-final/go.mod
        cp ${./go.sum} deps-final/go.sum
        chmod -R u+w deps-final
        (cd deps-final && go mod download all)

        # lisette fetches its bindgen tool at emit time via
        # `go run github.com/ivov/lisette/bindgen@v${lisette.version}`; pre-download
        # it and its dependency graph so emit runs fully offline.
        mkdir tools
        cat > tools/go.mod <<EOF
        module lisette-bindgen-tools

        go 1.25

        require github.com/ivov/lisette/bindgen v${lib.getVersion lisette}
        EOF
        (cd tools && go mod download all)

        mkdir -p "$out"
        cp -r "$GOMODCACHE/cache/download/." "$out"
      '';

  # Generates the project from the .lis sources. Runs offline (GOPROXY points
  # at the go-modules cache above), so this is a plain sandboxed derivation
  # with no output hash.
  lisProject =
    runCommand "lis-python-server-emitted"
      {
        nativeBuildInputs = [ go ];
      }
      /* sh */ ''
        export HOME="$TMPDIR"
        export GOCACHE="$TMPDIR/go-cache"
        export GOMODCACHE="$TMPDIR/go-mod-cache"
        export GOPROXY="file://${goModules},off"
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
    export GOPROXY="file://${goModules},off"
    export GOSUMDB=off
    export GOTOOLCHAIN=local
    export GOWORK=off
    export GOFLAGS="-buildvcs=false $GOFLAGS"
  '';

  nativeBuildInputs = [ lisette ];
  meta.mainProgram = manifest.project.name;
}
