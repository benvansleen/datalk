{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    gitignore.url = "github:hercules-ci/gitignore.nix";
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

    extra-container.url = "github:erikarvstedt/extra-container";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      extra-container,
      terranix,
      pre-commit-hooks,
      treefmt-nix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      eachSystem =
        f: lib.genAttrs lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system} system);

      domain = "datalk.vansleen.dev";
    in
    {
      packages = eachSystem (
        pkgs: system: {
          ui = pkgs.callPackage ./ui/package.nix inputs;
          python-server = pkgs.callPackage ./python-server/package.nix inputs;

          containers = extra-container.lib.buildContainers {
            inherit nixpkgs system;
            config = {
              ## FOR LOCAL DEVELOPMENT PURPOSES ONLY
              ## DO NOT DEPLOY UNPROTECTED CONTAINERS IN PRODUCTION
              containers = {
                py-sandbox = {
                  extra.addressPrefix = "10.250.1";
                  config =
                    { pkgs, ... }:
                    (lib.recursiveUpdate { } (
                      import ./nix/services/python-server.nix {
                        inherit self pkgs;
                        inherit (pkgs) lib;
                      }
                    ));
                };
                ui = {
                  extra.addressPrefix = "10.250.0";
                  config =
                    lib.recursiveUpdate
                      {

                        programs.extra-container.enable = true;
                        networking.firewall.allowedTCPPorts = [
                          80
                          443
                          3000
                          5432
                        ];

                        services.postgresql = {
                          enable = true;
                          enableJIT = true;
                          ensureUsers = [ { name = "postgres"; } ];
                          ensureDatabases = [ "datalk" ];
                          enableTCPIP = true;
                          settings = {
                            port = 5432;
                          };
                          initialScript = pkgs.writeText "init-sql-script" ''
                            ALTER USER postgres WITH PASSWORD 'postgres';
                          '';
                          authentication = ''
                            host all all 0.0.0.0/0 md5
                          '';
                        };

                        services.redis.servers."cache" = {
                          enable = true;
                          bind = "0.0.0.0";
                          port = 6379;
                          # user = "redis";
                          # group = "users";
                          requirePass = "letmein";
                          openFirewall = true;
                        };
                      }
                      (
                        import ./nix/services/ui { self-sign-certs = true; } {
                          inherit self pkgs;
                          inherit (pkgs) lib;
                        }
                      );
                };
              };
            };
          };
        }
      );

      nixosConfigurations = {
        ui = lib.nixosSystem {
          specialArgs = inputs;
          modules = [
            (import ./nix/systems/ui.nix { inherit domain; })
          ];
        };
      };

      apps = eachSystem (
        pkgs: system:
        let
          terraform = pkgs.opentofu;
          terraformConfiguration = terranix.lib.terranixConfiguration {
            inherit system;
            modules = [ (import ./tf { inherit domain; }) ];
          };
        in
        {
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
        }
      );

      devShells = eachSystem (
        pkgs: system: {
          default =
            with pkgs;
            mkShell {
              buildInputs = [
                self.checks.${system}.pre-commit-check.enabledPackages
                self.packages.${system}.ui.buildInputs
                self.packages.${system}.ui.nativeBuildInputs
                self.packages.${system}.ui.propagatedBuildInputs
              ];
              inherit (self.checks.${system}.pre-commit-check) shellHook;
              packages = with pkgs; [
                svelte-language-server

                self.packages.${pkgs.stdenv.hostPlatform.system}.python-server
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
        }
      );

      formatter = eachSystem (
        pkgs: _: (treefmt-nix.lib.evalModule pkgs ./treefmt.nix).config.build.wrapper
      );
      checks = eachSystem (
        _: system: {
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
                packageOverrides.treefmt = self.outputs.formatter.${system};
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
        }
      );
    };
}
