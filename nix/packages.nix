{ inputs, ... }:

{
  flake-file.inputs = {
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  perSystem =
    {
      inputs',
      self',
      pkgs,
      ...
    }:
    {
      packages = {
        ui = pkgs.callPackage ../ui inputs;
        python-server = pkgs.callPackage ../python-server inputs;

        datalk-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "datalk";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "datalk-image-root";
            paths = with self'.packages; [
              ui
              ui.site
              ui.migrate
            ];
            pathsToLink = [ "/" ];
          };
          config = {
            Cmd = [ "/bin/ui" ];
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            ];
          };
        };

        datalk-dev-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "datalk-dev";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "datalk-dev-image-root";
            paths = [
              self'.packages.ui.devRoot
              pkgs.nodejs_22
            ];
            pathsToLink = [ "/" ];
          };
          config = {
            Cmd = [
              "/bin/node"
              "/app/node_modules/vite/bin/vite.js"
              "--host"
              "0.0.0.0"
            ];
            WorkingDir = "/app";
            Env = [
              "NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            ];
          };
        };

        python-server-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "python-server";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "python-server-image-root";
            paths = with self'.packages; [
              python-server
              pkgs.gnutar
            ];
          };
          config.Cmd = [ "/bin/server" ];
        };
      };
    };
}
