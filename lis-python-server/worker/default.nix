{
  callPackage,
  lib,
  pyproject-build-systems,
  pyproject-nix,
  python313,
  uv2nix,
  ...
}:

let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./.;
  };

  workspaceOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet = (callPackage pyproject-nix.build.packages { python = python313; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      workspaceOverlay
    ]
  );
in
(pythonSet.mkVirtualEnv "lis-python-worker" workspace.deps.default).overrideAttrs {
  meta.mainProgram = "datalk-worker";
}
