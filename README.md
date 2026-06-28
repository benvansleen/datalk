
# Datalk
*Talk with your data!*

## Available flake outputs
- `nix run .#tf-[apply|destroy]`: deploy/destroy `terranix` configuration
- `nix run .#containers -- create --start`: spin up `docker compose`-like development containers (eg for db, redis)
- `nix run .#ui`: build & launch the SvelteKit application
- `nix run .#python-server`: build & launch the remote-execution python server
  - *NB: This is explicitly remote code execution over http! Must sandbox!*
- `nix run .#push-images-local`: build & push the production-style & development local k3d images
- `nixosConfigurations.ui`: main NixOS system serving the SvelteKit application
- `nix develop`:
  - Install pre-commit-hooks
  - Install LSP / package build inputs
- `nix fmt`:
  - TS/Svelte support pending!

## Available datasets
The python/sql execution environment expects a "dataset connector" to be a folder of `.csv` files. Each `.csv` will be loaded into a "table" / dataframe, and all tables within a dataset will be made available to any chat with that datasetenabled (1 chat <=> 1 dataset).

Currently, only a subset of the excellent (College Football Data)[https://collegefootballdata.com] (2025 only) has been "connected." More datasets could be easily uploaded to the sandbox container -- but I am concerned about overloading my limited computational resources in production!

## Local UI hot reload on k3d

The `local` Kubernetes environment can run the UI from a Nix-built dev image when `hotReload = true` in `nix/kubernetes/default.nix`. It mounts this checkout into the k3d nodes at `/workspace/datalk`. The pod mounts `ui/src`, `ui/static`, and `ui/drizzle` from there, so SvelteKit/Vite can reload without rebuilding the image for normal source edits.

If the k3d cluster already exists from before this mount was added, recreate it once with `nix run .#tf-destroy-local` and `nix run .#tf-apply-local`.

Use `nix run .#push-images-local` when Node dependencies or UI config baked into the dev image change.
