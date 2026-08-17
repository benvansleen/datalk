{ inputs, self, ... }:

{
  imports = [ inputs.terranix.flakeModule ];

  flake-file.inputs = {
    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  perSystem =
    {
      self',
      pkgs,
      lib,
      system,
      ...
    }:

    let
      terraform =
        with pkgs;
        opentofu.withPlugins (
          plugins: with plugins; [
            # gcloud container clusters get-credentials datalk --zone us-east4-a
            hashicorp_google
            hashicorp_external
            alekc_kubectl
          ]
        );

      imageKey = img: lib.replaceStrings [ "-" ] [ "_" ] img.imageName;
      pushRefs = imgs: map (img: "terraform_data.push_${imageKey img}") imgs;
    in
    {
      terranix = {
        exportDevShells = false;
        terranixConfigurations = {
          production =
            let
              context = "gke_${self.gcloud.project}_${self.gcloud.zone}_${self.gcloud.name}";
              manifest = self'.legacyPackages.nixidyEnvs.${system}.default;
              prepareContext = /* sh */ ''
                ${lib.getExe pkgs.google-cloud-sdk} container clusters get-credentials \
                  ${self.gcloud.name} \
                  --zone ${self.gcloud.zone} \
                  --project ${self.gcloud.project} >/dev/null 2>&1 || true
              '';
              imgs = with self.packages.${system}; [
                datalk-image
                celld-deploy-source-image
                lis-python-server-image
                lis-python-worker-image
              ];
            in
            {
              workdir = ".terraform/production";
              modules = with self.modules.infra; [
                production
                {
                  imports = [ nixidy-kubectl ];
                  nixidyKubectl = {
                    env = manifest;
                    wait = true;
                    extraDependsOn = [
                      "google_container_cluster.${self.gcloud.name}"
                      "terraform_data.propagate_secrets"
                    ]
                    ++ pushRefs imgs;
                  };
                  provider.kubectl = {
                    config_path = "~/.kube/config";
                    config_context = context;
                  };
                  terraform.required_providers = {
                    google = {
                      source = "hashicorp/google";
                      version = "7.42.0";
                    };
                    external = {
                      source = "hashicorp/external";
                      version = "2.4.0";
                    };
                    kubectl = {
                      source = "alekc/kubectl";
                      version = "2.4.1";
                    };
                  };
                }
              ];
              terraformWrapper = {
                package = terraform;
                prefixText = prepareContext;
              };
            };
          local =
            let
              context = "k3d-${self.gcloud.name}-local";
              manifest = self'.legacyPackages.nixidyEnvs.${system}.local;
              imgs = with self.packages.${system}; [
                datalk-image
                datalk-dev-image
                celld-dev-image
                lis-python-server-image
                lis-python-worker-image
              ];
            in
            {
              ## bootstrap with
              # `nix run .#local.terraform -- apply -target=terraform_data.k3d_cluster`
              modules = with self.modules.infra; [
                k3d
                {
                  imports = [ nixidy-kubectl ];
                  nixidyKubectl = {
                    env = manifest;
                    wait = false;
                    extraDependsOn = [
                      "terraform_data.k3d_cluster"
                      "terraform_data.local_secrets"
                    ]
                    ++ pushRefs imgs;
                  };
                  provider.kubectl = {
                    config_path = "~/.kube/config";
                    config_context = context;
                  };
                  terraform.required_providers = {
                    external = {
                      source = "hashicorp/external";
                      version = "2.4.0";
                    };
                    kubectl = {
                      source = "alekc/kubectl";
                      version = "2.4.1";
                    };
                  };
                }
              ];
              workdir = ".terraform/local";
              terraformWrapper = {
                package = terraform;
              };
            };
        };
      };
    };

  flake.image-tag = img: builtins.substring 11 32 (toString img.outPath);
}
