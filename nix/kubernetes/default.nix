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
        datalk
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
        datalk = {
          enable = true;
          image = self.image-uri self.packages.x86_64-linux.datalk-image;
        };
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
        push-images =
          ## gcloud auth configure-docker us-east4-docker.pkg.dev
          let
            img = self'.packages.datalk-image;
          in
          {
            type = "app";
            program =
              (pkgs.writeShellScript "push-images" /* bash */ ''
                set -euo pipefail

                image="docker://${self.image-uri img}"
                echo "pushing $image"
                ${img.copyTo}/bin/copy-to "$image"
              '').outPath;
          };
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

  flake.image-uri =
    let
      inherit (self.gcloud) project region name;
    in
    img: "${region}-docker.pkg.dev/${project}/${name}/${img.imageName}:git-${self.shortRev or "dirty"}";
}
