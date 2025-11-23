{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    gitignore.url = "github:hercules-ci/gitignore.nix";

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
    in
    {
      packages = eachSystem (
        pkgs: system: {
          ui = pkgs.callPackage ./ui/package.nix inputs;

          containers = extra-container.lib.buildContainers {
            inherit nixpkgs system;
            config = {
              containers = {
                ui = {
                  extra.addressPrefix = "10.250.0";
                  config =
                    { pkgs, ... }:
                    let
                      port = 3000;
                    in
                    {
                      systemd.services.ui = {
                        wantedBy = [ "multi-user.target" ];
                        serviceConfig = {
                          ExecStart = "${self.packages.${system}.ui}/bin/ui";
                          Restart = "always";
                          Environment = "PORT=${toString port}";
                        };
                      };
                      services.nginx = {
                        enable = true;
                        recommendedGzipSettings = true;
                        recommendedOptimisation = true;
                        recommendedProxySettings = true;
                        recommendedTlsSettings = true;
                        virtualHosts."localhost" = {
                          forceSSL = true;
                          sslTrustedCertificate = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
                          sslCertificate = ./certs/localhost.crt;
                          sslCertificateKey = ./certs/localhost.key;
                          locations = {
                            "/" = {
                              proxyPass = "http://localhost:${toString port}";
                            };
                          };
                        };
                      };
                    };
                };
              };
            };
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
              ];
            };
        }
      );

      apps = eachSystem (
        pkgs: system:
        let
          terraform = pkgs.opentofu;
          terraformConfiguration = terranix.lib.terranixConfiguration {
            inherit system;
            modules = [ ./tf ];
          };
        in
        {
          apply = {
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
          destroy = {
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
