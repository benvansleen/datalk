{ pkgs, gitignore, ... }:

let
  inherit (gitignore.lib) gitignoreSource;
in
pkgs.python313Packages.buildPythonApplication rec {
  version = "0.1.0";
  pname = "server";
  src = gitignoreSource ./.;
  dependencies = with pkgs.python313Packages; [
    fastapi
    pydantic
    uvicorn

    notebook
  ];
  pyproject = true;
  meta.mainProgram = pname;
}
