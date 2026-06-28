{ inputs, ... }:

{
  flake-file.inputs = {
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  };

  imports = [ inputs.process-compose-flake.flakeModule ];

  perSystem =
    {
      self',
      pkgs,
      lib,
      ...
    }:
    let
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
    in
    {
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
    };
}
