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

  dependencyVersion =
    dependency: if builtins.isString dependency then dependency else dependency.version;

  goDependencies = manifest.dependencies.go // {
    "github.com/ivov/lisette/bindgen" = "v${lisette.version}";
    "github.com/ivov/lisette/prelude" = "v${lisette.version}";
  };

  goRequirements = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      module: dependency: "\t${module} ${dependencyVersion dependency}"
    ) goDependencies
  );

  goDependencySource = runCommand "lis-python-server-go-dependency-source" { } /* sh */ ''
    mkdir "$out"
    cat > "$out/go.mod" <<'EOF'
    module lis-python-server-dependencies

    go ${lib.versions.majorMinor go.version}

    require (
    ${goRequirements}
    )
    EOF
  '';

  goDependencyPackage = buildGoModule {
    pname = "lis-python-server-go-dependencies";
    inherit (manifest.project) version;
    src = goDependencySource;
    proxyVendor = true;
    vendorHash = "sha256-I91LRaUWV5EObPuHGxxT/zedG/O6ujXxqyUE6ZalKeg=";

    modPostBuild = /* sh */ ''
      go mod download all
      go mod download \
        cloud.google.com/go/compute/metadata@v0.7.0 \
        github.com/go-logr/logr@v1.2.2 \
        github.com/go-logr/logr@v1.4.3 \
        github.com/golang/protobuf@v1.5.4 \
        gonum.org/v1/gonum@v0.16.0

      mkdir "$TMPDIR/bindgen-dependencies"
      cp \
        "$GOPATH/pkg/mod/cache/download/github.com/ivov/lisette/bindgen/@v/v${lisette.version}.mod" \
        "$TMPDIR/bindgen-dependencies/go.mod"
      (cd "$TMPDIR/bindgen-dependencies" && go mod download all)
    '';
  };

  goModuleProxy = goDependencyPackage.goModules;

  generatedGo =
    runCommand "lis-python-server-generated-go"
      {
        nativeBuildInputs = [
          go
        ];
      }
      /* sh */ ''
        export HOME="$TMPDIR"
        export GOCACHE="$TMPDIR/go-cache"
        export GOMODCACHE="$TMPDIR/go-mod-cache"
        export GOPROXY="file://${goModuleProxy}"
        export GOSUMDB=off
        export GOTOOLCHAIN=local

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
  proxyVendor = true;
  vendorHash = null;
  ldflags = [
    "-s"
    "-w"
  ];

  postConfigure = /* sh */ ''
    export GOPROXY="file://${goModuleProxy}"
    export GOSUMDB=off
  '';

  nativeBuildInputs = [ lisette ];
  meta.mainProgram = manifest.project.name;
}
