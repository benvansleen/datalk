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
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
      };
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
      };
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
        lis-python-server = pkgs.callPackage ../lis-python-server inputs;
        lis-python-worker = pkgs.callPackage ../lis-python-server/worker inputs;

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

        lis-python-server-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "lis-python-server";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "lis-python-server-image-root";
            paths = [ self'.packages.lis-python-server ];
            pathsToLink = [ "/" ];
          };
          config = {
            Cmd = [ "/bin/lis-python-server" ];
            Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
            User = "1000:1000";
          };
        };

        lis-python-worker-image = inputs'.nix2container.packages.nix2container.buildImage {
          name = "lis-python-worker";
          tag = "local";
          copyToRoot = pkgs.buildEnv {
            name = "lis-python-worker-image-root";
            paths = [ self'.packages.lis-python-worker ];
            pathsToLink = [ "/" ];
          };
          config = {
            Cmd = [ "/bin/datalk-worker" ];
            Env = [
              "PYTHONDONTWRITEBYTECODE=1"
              "PYTHONUNBUFFERED=1"
            ];
            User = "1000:1000";
          };
        };
      };
    };
}
