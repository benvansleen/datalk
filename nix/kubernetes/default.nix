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
          celld
          datalk
          external-secrets
          lis-python-server
          seaweedfs
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
          celld = {
            enable = true;
            deploySourceImage = self.image-uri self.packages.x86_64-linux.celld-deploy-source-image;
            liveOrigin = "https://datalk.clouded-mimosa.ts.net";
          };
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
            image = self.image-uri self.packages.x86_64-linux.lis-python-server-image;
            workerImage = self.image-uri self.packages.x86_64-linux.lis-python-worker-image;
            datasetGcsBucket = "datalk-datasets";
            checkpointStorageClass = "standard";
          };
          seaweedfs.enable = true;
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
          celld
          datalk
          lis-python-server
          observability
          seaweedfs
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
          celld = {
            enable = true;
            image = self.local-image-uri self.packages.x86_64-linux.celld-dev-image;
            dev.enable = hotReload;
            liveOrigin = "http://localhost:8080";
          };
          observability.enable = true;
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
            image = self.local-image-uri self.packages.x86_64-linux.lis-python-server-image;
            workerImage = self.local-image-uri self.packages.x86_64-linux.lis-python-worker-image;
            datasetHostPath = "/workspace/datalk/datasets";
          };
          seaweedfs.enable = true;
          valkey.enable = true;
        };
      };
  };

  perSystem =
    {
      inputs',
      pkgs,
      lib,
      system,
      ...
    }:
    let
      seaweedfsOperatorChart =
        let
          src = pkgs.fetchFromGitHub {
            owner = "seaweedfs";
            repo = "seaweedfs-operator";
            rev = "afef5cd8e1e6bc0f22d37b18437b5f7708ee5762";
            hash = "sha256-up0K0UrXnMTj9LLVhSaXdeUMRcasFsiHUCogyxplKP4=";
          };
        in
        pkgs.runCommand "seaweedfs-operator-chart" { } ''
          cp -r ${src}/deploy/helm $out
        '';
      charts = inputs.nixhelm.chartsDerivations.${system} // {
        seaweedfs-operator = {
          seaweedfs-operator = seaweedfsOperatorChart;
        };
      };
    in
    {
      packages = {
        nixidy = inputs'.nixidy.packages.default.overrideAttrs (old: {
          meta.mainProgram = old.meta.mainProgram or "nixidy";
        });
      };

      legacyPackages = {
        nixidyEnvs.${system} = inputs.nixidy.lib.mkEnvs {
          inherit pkgs charts;
          envs = {
            default.modules = [ self.modules.kubernetes.default ];
            local.modules = [ self.modules.kubernetes.local ];
          };
        };
      };

      apps = {
        generate =
          let
            inherit (inputs'.nixidy.packages.generators) fromChartCRD;
            toGenerate = {
              cloudnative-pg = fromChartCRD {
                name = "cloudnative-pg";
                chart = inputs.nixhelm.chartsDerivations.${system}.cloudnative-pg.cloudnative-pg;
              };
              external-secrets = fromChartCRD {
                name = "external-secrets";
                chart = inputs.nixhelm.chartsDerivations.${system}.external-secrets.external-secrets;
              };
              tailscale-operator = fromChartCRD {
                name = "tailscale";
                chart = inputs.nixhelm.chartsDerivations.${system}.tailscale.tailscale-operator;
              };
              seaweedfs-operator = fromChartCRD {
                name = "seaweedfs-operator";
                chart = seaweedfsOperatorChart;
              };
            };
            generatedOutputDir = "nix/kubernetes/_generated";
            generate =
              with lib;
              pipe toGenerate [
                (mapAttrsToList (
                  name: generator: /* sh */ ''
                    cat ${generator} > "${generatedOutputDir}/${name}.nix"
                  ''
                ))
                (concatStringsSep "\n")
              ];
          in
          {
            type = "app";
            program =
              (pkgs.writeShellScript "generate-crds" /* sh */ ''
                set -eo pipefail

                mkdir -p "${generatedOutputDir}"
                ${generate}
              '').outPath;
          };
      };
    };
}
