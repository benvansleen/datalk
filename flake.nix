{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    secrets = {
      url = "git+ssh://git@github.com/benvansleen/datalk-secrets.git";
      # url = "path:/home/ben/Code/datalk/secrets";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        gitignore.follows = "gitignore";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      process-compose-flake,
      terranix,
      pre-commit-hooks,
      treefmt-nix,
      ...
    }:
    let
      domain = "datalk.vansleen.dev";
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ process-compose-flake.flakeModule ];

      flake = {
        nixosConfigurations = {
          ui = nixpkgs.lib.nixosSystem {
            specialArgs = inputs;
            modules = [ (import ./nix/systems/ui.nix { inherit domain; }) ];
          };
        };
      };

      perSystem =
        {
          pkgs,
          system,
          self',
          ...
        }:
        let
          inherit (pkgs) lib;
          postgresDataDir = ".data/postgres";
          redisDataDir = ".data/redis";
          postgresScript = pkgs.writeShellApplication {

            name = "datalk-postgres";
            runtimeInputs = [ pkgs.postgresql ];
            text = ''
              set -euo pipefail

              postgres_user="postgres"
              postgres_password="postgres"
              postgres_db="datalk"
              postgres_port="5432"
              postgres_host="127.0.0.1"
              base_dir="$(pwd)"
              postgres_root="${postgresDataDir}"
              postgres_pgdata="$base_dir/$postgres_root/data"
              postgres_socket_dir="$base_dir/$postgres_root/socket"

              mkdir -p "$base_dir/$postgres_root" "$postgres_pgdata" "$postgres_socket_dir"

              if [ ! -s "$postgres_pgdata/PG_VERSION" ]; then
                if [ -n "$(ls -A "$postgres_pgdata" 2>/dev/null)" ]; then
                  echo "Postgres data directory is not empty: $postgres_pgdata" >&2
                  echo "Remove or empty it to reinitialize." >&2
                  exit 1
                fi

                pwfile="${postgresDataDir}/pwfile"
                printf '%s' "$postgres_password" > "$pwfile"
                initdb \
                  --username "$postgres_user" \
                  --pwfile "$pwfile" \
                  --auth=md5 \
                  --encoding=UTF8 \
                  --pgdata "$postgres_pgdata"
                rm -f "$pwfile"
              fi

              export PGPASSWORD="$postgres_password"
              pg_ctl \
                -D "$postgres_pgdata" \
                -o "-c listen_addresses=$postgres_host -p $postgres_port -k $postgres_socket_dir" \
                -w start

              if ! psql -qtA -h "$postgres_host" -p "$postgres_port" -U "$postgres_user" \
                -c "SELECT 1 FROM pg_database WHERE datname='$postgres_db'" | grep -q 1; then
                createdb -U "$postgres_user" -h "$postgres_host" -p "$postgres_port" "$postgres_db"
              fi

              pg_ctl -D "$postgres_pgdata" -m fast -w stop

              exec postgres \
                -D "$postgres_pgdata" \
                -c "listen_addresses=$postgres_host" \
                -c "unix_socket_directories=$postgres_socket_dir" \
                -p "$postgres_port"
            '';
          };
          redisScript = pkgs.writeShellApplication {
            name = "datalk-redis";
            runtimeInputs = [ pkgs.redis ];
            text = ''
              set -euo pipefail

              redis_password="letmein"
              redis_port="6379"
              redis_host="127.0.0.1"

              mkdir -p "${redisDataDir}"

              exec redis-server \
                --bind "$redis_host" \
                --port "$redis_port" \
                --requirepass "$redis_password" \
                --dir "${redisDataDir}"
            '';
          };
          jaegerScript = pkgs.writeShellApplication {
            name = "datalk-jaeger";
            runtimeInputs = [ pkgs.podman ];
            text = ''
              set -euo pipefail

              exec podman run --name jaeger --rm --replace \
                -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
                -e COLLECTOR_OTLP_ENABLED=true \
                -p 127.0.0.1:6831:6831/udp \
                -p 127.0.0.1:6832:6832/udp \
                -p 127.0.0.1:5778:5778 \
                -p 127.0.0.1:16686:16686 \
                -p 127.0.0.1:4317:4317 \
                -p 127.0.0.1:4318:4318 \
                -p 127.0.0.1:14250:14250 \
                -p 127.0.0.1:14268:14268 \
                -p 127.0.0.1:14269:14269 \
                -p 127.0.0.1:9411:9411 \
                jaegertracing/all-in-one:latest
            '';
          };
          terraform = pkgs.opentofu;
          terraformConfiguration = terranix.lib.terranixConfiguration {
            inherit system;
            modules = [ (import ./tf { inherit domain; }) ];
          };
        in
        {
          packages = {
            ui = pkgs.callPackage ./ui inputs;
            python-server = pkgs.callPackage ./python-server inputs;
          };

          process-compose.dev-services = {
            settings = {
              version = "0.5";
              processes = {
                postgres.command = "${lib.getExe postgresScript}";
                redis.command = "${lib.getExe redisScript}";
                jaeger.command = "${lib.getExe jaegerScript}";
                python-server = {
                  command = "cd ./python-server && ${lib.getExe self'.packages.python-server}";
                };
              };
            };
          };

          apps = {
            tf-apply = {
              type = "app";
              program = toString (
                pkgs.writers.writeBash "apply" ''
                  [[ -e config.tf.json ]] && rm -f config.tf.json
                  cp ${terraformConfiguration} config.tf.json \
                  && ${lib.getExe terraform} init \
                  && ${lib.getExe terraform} apply
                ''
              );
            };
            tf-destroy = {
              type = "app";
              program = toString (
                pkgs.writers.writeBash "destroy" ''
                  [[ -e config.tf.json ]] && rm -f config.tf.json
                  cp ${terraformConfiguration} config.tf.json \
                  && ${lib.getExe terraform} init \
                  && ${lib.getExe terraform} destroy
                ''
              );
            };
          };

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

          formatter = (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.wrapper;
          checks = {
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                check-added-large-files.enable = true;
                check-merge-conflicts.enable = true;
                detect-private-keys.enable = true;
                deadnix.enable = true;
                end-of-file-fixer.enable = true;
                flake-checker.enable = true;
                ripsecrets.enable = true;
                statix.enable = true;
                treefmt = {
                  enable = true;
                  packageOverrides.treefmt = self'.formatter;
                };
                typos = {
                  enable = true;
                  settings = {
                    diff = false;
                    ignored-words = [
                    ];
                  };
                };
              };
            };
          };
        };
    };
}
