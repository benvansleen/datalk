{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells.default =
        with pkgs;
        mkShell {
          inputsFrom = builtins.attrValues self'.packages;
          buildInputs = self'.checks.pre-commit-check.enabledPackages;
          inherit (self'.checks.pre-commit-check) shellHook;
          packages = with pkgs; [
            self'.packages.nixidy
            (google-cloud-sdk.withExtraComponents (
              with google-cloud-sdk.components;
              [
                gke-gcloud-auth-plugin
              ]
            ))

            svelte-language-server
            oxlint
            podman

            uv

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
