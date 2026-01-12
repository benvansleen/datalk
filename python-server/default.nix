{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  name = "python-server";
  propagatedBuildInputs = [
    (pkgs.python313.withPackages (
      pypkg: with pypkg; [
        fastapi
        uvicorn
        pydantic
        notebook
        pandas
        duckdb
      ]

    ))

  ];
  dontUnpack = true;
  installPhase = "install -Dm755 ${./src/main.py} $out/bin/server";
  meta.mainProgram = "server";
}
