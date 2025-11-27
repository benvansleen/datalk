
# Datalk
*Talk with your data!*

## Available flake outputs
- `nix run .#tf-[apply|destroy]`: deploy/destroy `terranix` configuration
- `nix run .#containers -- create --start`: spin up `docker compose`-like development containers (eg for db, redis)
- `nix run .#ui`: build & launch the SvelteKit application
- `nix run .#python-server`: build & launch the remote-execution python server
  - *NB: This explicitly remote code execution over http! Must sandbox!*
- `nixosConfigurations.ui`: main NixOS system serving the SvelteKit application
- `nix develop`:
  - Install pre-commit-hooks
  - Install LSP / package build inputs
- `nix fmt`:
  - TS/Svelte support pending!

## Available datasets
The python/sql execution environment expects a "dataset connector" to be a folder of `.csv` files. Each `.csv` will be loaded into a "table" / dataframe, and all tables within a dataset will be made available to any chat with that datasetenabled (1 chat <=> 1 dataset).

Currently, only a subset of the excellent (College Football Data)[https://collegefootballdata.com] (2025 only) has been "connected." More datasets could be easily uploaded to the sandbox container -- but I am concerned about overloading my limited computational resources in production!
