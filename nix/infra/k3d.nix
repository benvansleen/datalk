{ self, ... }:

{
  flake = {
    local-image-uri = img: "k3d-datalk-local-registry:5000/${img.imageName}:${self.image-tag img}";
    local-image-push-uri = img: "localhost:5001/${img.imageName}:${self.image-tag img}";

    modules.infra.k3d =
      {
        pkgs,
        lib,
        ...
      }:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        k3d = lib.getExe pkgs.k3d;
        git = lib.getExe pkgs.git;
        kubectl = lib.getExe pkgs.kubectl;
        podman = lib.getExe pkgs.podman;
        imgs = with self.packages.${system}; [
          datalk-image
          datalk-dev-image
          python-server-image
        ];
        # `systemctl --user enable --now podman.socket`
        podmanConfig = /* sh */ ''
          if [ -z "$XDG_RUNTIME_DIR" ]; then
            XDG_RUNTIME_DIR="/run/user/$(id -u)"
          fi
          export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
          export DOCKER_SOCK="$XDG_RUNTIME_DIR/podman/podman.sock"
        '';
        cluster = "${self.gcloud.name}-local";
        registry = {
          name = "${cluster}-registry";
          port = "5001";
        };
        manifest = self.legacyPackages.${system}.nixidyEnvs.${system}.local.declarativePackage;
      in
      {
        resource = {
          terraform_data = {
            apply_local = {
              triggers_replace.manifest = toString manifest;
              depends_on = [
                "terraform_data.k3d_cluster"
                "terraform_data.local_secrets"
              ]
              ++ map (img: "terraform_data.push_${img.imageName}") imgs;
              provisioner.local-exec.command = /* sh */ ''
                repo_root="$(${git} rev-parse --show-toplevel)"
                cd "$repo_root"
                ${kubectl} config use-context k3d-${self.gcloud.name}-local
                ${lib.getExe self.packages.${system}.nixidy} apply .#local
              '';
            };

            local_secrets =
              let
                ## relative to .terraform/local/
                secretsFile = "../../.env.local.k8s";
              in
              {
                input.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                triggers_replace.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
                depends_on = [
                  "terraform_data.k3d_cluster"
                ];
                provisioner.local-exec.command = /* sh */ ''
                  set -euo pipefail

                  if [ ! -f ${secretsFile} ]; then
                    echo "missing ${secretsFile}" >&2
                    exit 1
                  fi

                  ${kubectl} create namespace datalk \
                    --dry-run=client \
                    -o yaml \
                    | ${kubectl} apply -f -
                  ${kubectl} create secret generic datalk-runtime \
                    -n datalk \
                    --from-env-file=${secretsFile} \
                    --dry-run=client \
                    -o yaml \
                    | ${kubectl} apply -f -
                '';
              };

            k3d_cluster =
              let
                k3dConfig = (pkgs.formats.yaml { }).generate "k3d-${cluster}.yaml" {
                  apiVersion = "k3d.io/v1alpha5";
                  kind = "Simple";
                  metadata.name = cluster;
                  image = "rancher/k3s:v1.34.9-k3s1";
                  servers = 1;
                  agents = 3;
                  kubeAPI = {
                    hostIP = "127.0.0.1";
                    hostPort = "6445";
                  };
                  ports = [
                    {
                      port = "8080:80";
                      nodeFilters = [ "loadbalancer" ];
                    }
                    {
                      port = "8443:443";
                      nodeFilters = [ "loadbalancer" ];
                    }
                  ];
                  options = {
                    k3d = {
                      wait = true;
                      timeout = "2m";
                      disableLoadbalancer = false;
                      disableImageVolume = false;
                    };
                    k3s = {
                      extraArgs = [
                        {
                          ## necessary for running k3d on rootless podman
                          arg = "--kubelet-arg=feature-gates=KubeletInUserNamespace=true";
                          nodeFilters = [
                            "server:*"
                            "agent:*"
                          ];
                        }
                      ];
                      nodeLabels = [
                        {
                          label = "workload=datalk";
                          nodeFilters = [ "agent:*" ];
                        }
                      ];
                    };
                    kubeconfig = {
                      updateDefaultKubeconfig = true;
                      switchCurrentContext = true;
                    };
                  };
                };
              in
              {
                input = {
                  cluster_name = cluster;
                  config_sha = "\${filesha256(\"${k3dConfig}\")}";
                };
                triggers_replace = {
                  cluster_name = cluster;
                  config_sha = "\${filesha256(\"${k3dConfig}\")}";
                };

                provisioner.local-exec = [
                  {
                    command = /* sh */ ''
                      ${podmanConfig}
                      if ${k3d} cluster list ${cluster} >/dev/null 2>&1; then
                        echo "k3d cluster ${cluster} already exists"
                      else
                        repo_root="$(${git} rev-parse --show-toplevel)"
                        ${k3d} cluster create \
                          --config ${k3dConfig} \
                          --network ${cluster} \
                          --volume "$repo_root:/workspace/datalk@all" \
                          --registry-use "k3d-${registry.name}:5000"
                      fi
                    '';
                  }
                  {
                    when = "destroy";
                    command = /* sh */ ''
                      ${podmanConfig}
                      ${k3d} cluster delete ${cluster}
                    '';
                  }
                ];
                depends_on = [
                  "terraform_data.k3d_registry"
                ];
              };

            k3d_registry = {
              input = {
                registry_name = registry.name;
                host_port = registry.port;
              };
              triggers_replace = {
                registry_name = registry.name;
                host_port = registry.port;
              };
              depends_on = [
                "terraform_data.k3d_network"
              ];

              provisioner.local-exec = [
                {
                  command = /* sh */ ''
                    ${podmanConfig}
                    if ${k3d} registry list ${registry.name} >/dev/null 2>&1; then
                      echo "k3d registry ${registry.name} already exists"
                    else
                      ${k3d} registry create ${registry.name} \
                        --port "0.0.0.0:${registry.port}" \
                        --default-network ${cluster}
                    fi
                  '';
                }
                {
                  when = "destroy";
                  command = /* sh */ ''
                    ${podmanConfig}
                    ${k3d} registry delete ${registry.name}
                  '';
                }
              ];
            };

            k3d_network = {
              input.network_name = cluster;
              triggers_replace.network_name = cluster;

              provisioner.local-exec = [
                {
                  command = /* sh */ ''
                    ${podmanConfig}
                    if ${podman} network exists ${cluster}; then
                      echo "podman network ${cluster} already exists"
                    else
                      ${podman} network create ${cluster}
                    fi
                  '';
                }
                {
                  when = "destroy";
                  command = /* sh */ ''
                    ${podmanConfig}
                    ${podman} network rm ${cluster}
                  '';
                }
              ];
            };
          }
          // (builtins.listToAttrs (
            map (img: {
              name = "push_${img.imageName}";
              value = {
                triggers_replace = "${img}";
                input = self.local-image-push-uri img;
                depends_on = [ "terraform_data.k3d_registry" ];
                provisioner.local-exec.command = /* sh */ ''
                  uri="docker://''${self.input}"
                  echo "pushing $uri"
                  ${img.copyTo}/bin/copy-to --dest-tls-verify=false "$uri"
                '';
              };
            }) imgs
          ));
        };

      };
  };
}
