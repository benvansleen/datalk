{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    extra-container.url = "github:erikarvstedt/extra-container";
    gitignore.url = "github:hercules-ci/gitignore.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      extra-container,
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
          ui = pkgs.callPackage ./nix/ui.nix inputs;

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
                          ExecStart = lib.getExe self.packages.${system}.ui;
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
    };
}
