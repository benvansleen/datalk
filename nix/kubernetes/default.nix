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

  flake.modules.kubernetes.default =
    { lib, ... }:
    {
      imports = with self.modules.kubernetes; [
        external-secrets
        tailscale-operator
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
        external-secrets.enable = true;
        tailscale-operator.enable = true;
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
        nixidy = inputs'.nixidy.packages.default;
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
          };
        };
      };

      apps = {
        generate = {
          type = "app";
          program =
            (pkgs.writeShellScript "generate-crds" /* bash */ ''
              set -eo pipefail

              cat ${self'.packages."generators/external-secrets"} > nix/_generated/external-secrets.nix
              cat ${self'.packages."generators/tailscale"} > nix/_generated/tailscale-operator.nix
            '').outPath;
        };
      };
    };
}
