
# Datalk
*Talk with your data!*

## Available flake outputs
- `nix run .#local`: deploy dev environment to `k3d`
  - first run: bootstrap the cluster via `nix run .#local.terraform -- apply -target=terraform_data.k3d_cluster`
- `nix run .#production`: ensure infrastructure exists and deploy the application
- `nix develop`:
  - Install pre-commit-hooks
  - Install LSP / package build inputs
- `nix fmt`

## Available datasets
The python/sql execution environment expects a "dataset connector" to be a folder of `.csv` files. Each `.csv` will be loaded into a "table" / dataframe, and all tables within a dataset will be made available to any chat with that datasetenabled (1 chat <=> 1 dataset).
