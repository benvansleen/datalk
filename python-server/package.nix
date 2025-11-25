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
      ]
    ))
  ];
  dontUnpack = true;
  installPhase = "install -Dm755 ${./src/main.py} $out/bin/python-server";
}
