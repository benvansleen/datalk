
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
