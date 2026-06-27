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

  flake.modules.kubernetes =
    let
      target = {
        repository = "https://github.com/benvansleen/datalk.git";
        branch = "master";
        rootPath = "./manifests/default";
      };
    in
    {
      default =
        { lib, ... }:
        {
          imports = with self.modules.kubernetes; [
            datalk
            external-secrets
            tailscale-operator
          ];

          nixidy = {
            inherit target;
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

      local = {
        imports = with self.modules.kubernetes; [
          cloudnative-pg
          datalk
          valkey
        ];
        nixidy = {
          target = {
            rootPath = "./manifests/k3s";
            repository = "";
            branch = "";
          };
        };
        modules = {
          cloudnative-pg.enable = true;
          valkey.enable = true;
          datalk = {
            enable = true;
            image = self.local-image-uri self.packages.x86_64-linux.datalk-image;
            publicUrl = "http://datalk.localhost:8080";
            localIngress = "datalk.localhost";
          };
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
        nixidy = inputs'.nixidy.packages.default;
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

              cat ${self'.packages."generators/cloudnative-pg"} > nix/_generated/cloudnative-pg.nix
              cat ${self'.packages."generators/external-secrets"} > nix/_generated/external-secrets.nix
              cat ${self'.packages."generators/tailscale"} > nix/_generated/tailscale-operator.nix
            '').outPath;
        };
        push-images-local =
          let
            img = self'.packages.datalk-image;
          in
          {
            type = "app";
            program =
              (pkgs.writeShellScript "push-images-local" /* bash */ ''
                set -euo pipefail

                image="docker://${self.local-image-push-uri img}"
                echo "pushing $image"
                ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$image"
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
