{ inputs, self, ... }:

{
  flake-file.inputs = {
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.modules.kubernetes = {
    default =
      { lib, ... }:
      {
        imports = with self.modules.kubernetes; [
          cloudnative-pg
          datalk
          external-secrets
          python-server
          tailscale-operator
          valkey
        ];

        nixidy = {
          target = {
            repository = "https://github.com/benvansleen/datalk.git";
            branch = "master";
            rootPath = "./manifests/default";
          };
          defaults.helm.transformer = map (
            lib.kube.removeLabels [
              "app.kubernetes.io/version"
              "helm.sh/chart"
            ]
          );
        };

        modules = {
          cloudnative-pg.enable = true;
          datalk = {
            enable = true;
            image = self.image-uri self.packages.x86_64-linux.datalk-image;
            publicUrl = "https://datalk.clouded-mimosa.ts.net";
            environment = "production";
            ingress = {
              type = "tailscale";
              host = "datalk.clouded-mimosa.ts.net";
            };
            runtimeExternalSecret.enable = true;
          };
          external-secrets.enable = true;
          python-server = {
            enable = true;
            image = self.image-uri self.packages.x86_64-linux.python-server-image;
          };
          tailscale-operator.enable = true;
          valkey.enable = true;
        };
      };

    local =
      let
        hotReload = true;
      in
      {
        imports = with self.modules.kubernetes; [
          cloudnative-pg
          datalk
          python-server
          valkey
        ];
        nixidy = {
          target = {
            rootPath = "./manifests/local";
            repository = "";
            branch = "";
          };
        };
        modules = {
          cloudnative-pg.enable = true;
          datalk = {
            enable = true;
            dev.enable = hotReload;
            image = self.local-image-uri (
              with self.packages.x86_64-linux; if hotReload then datalk-dev-image else datalk-image
            );
            publicUrl = "http://localhost:8080";
            ingress = {
              type = "local";
              host = "localhost";
            };
          };
          python-server = {
            enable = true;
            image = self.local-image-uri self.packages.x86_64-linux.python-server-image;
          };
          valkey.enable = true;
        };
      };
  };

  perSystem =
    {
      inputs',
      self',
      pkgs,
      system,
      ...
    }:
    {
      packages = {
        nixidy = inputs'.nixidy.packages.default.overrideAttrs (old: {
          meta.mainProgram = old.meta.mainProgram or "nixidy";
        });
        "generators/cloudnative-pg" = inputs'.nixidy.packages.generators.fromChartCRD {
          name = "cloudnative-pg";
          chart = inputs.nixhelm.chartsDerivations.${system}.cloudnative-pg.cloudnative-pg;
        };
        "generators/external-secrets" = inputs'.nixidy.packages.generators.fromChartCRD {
          name = "external-secrets";
          chart = inputs.nixhelm.chartsDerivations.${system}.external-secrets.external-secrets;
        };
        "generators/tailscale" = inputs'.nixidy.packages.generators.fromChartCRD {
          name = "tailscale";
          chart = inputs.nixhelm.chartsDerivations.${system}.tailscale.tailscale-operator;
        };
      };

      legacyPackages = {
        nixidyEnvs.${system} = inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = inputs.nixhelm.chartsDerivations.${system};
          envs = {
            default.modules = [ self.modules.kubernetes.default ];
            local.modules = [ self.modules.kubernetes.local ];
          };
        };
      };

      apps = {
        generate = {
          type = "app";
          program =
            (pkgs.writeShellScript "generate-crds" /* bash */ ''
              set -eo pipefail

              mkdir -p nix/kubernetes/_generated
              cat ${self'.packages."generators/cloudnative-pg"} > nix/kubernetes/_generated/cloudnative-pg.nix
              cat ${self'.packages."generators/external-secrets"} > nix/kubernetes/_generated/external-secrets.nix
              cat ${self'.packages."generators/tailscale"} > nix/kubernetes/_generated/tailscale-operator.nix
            '').outPath;
        };
      };
    };
}
