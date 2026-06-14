{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells.default =
        with pkgs;
        mkShell {
          buildInputs = [
            self'.checks.pre-commit-check.enabledPackages
            self'.packages.ui.buildInputs
            self'.packages.ui.nativeBuildInputs
            self'.packages.ui.propagatedBuildInputs
          ];
          inherit (self'.checks.pre-commit-check) shellHook;
          packages = with pkgs; [
            (google-cloud-sdk.withExtraComponents (
              with google-cloud-sdk.components;
              [
                gke-gcloud-auth-plugin
              ]
            ))

            svelte-language-server
            oxlint
            podman

            self'.packages.python-server
            self'.packages.dev-services
            (python313.withPackages (
              pypkg: with pypkg; [
                duckdb
                matplotlib
                notebook
                pandas
                pydantic
                requests
                seaborn
                fastapi
                fastapi-cli
                uvicorn
                jupyter
              ]
            ))
          ];
        };
    };
}
