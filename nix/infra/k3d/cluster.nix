{ self, ... }:

{
  flake.modules.infra.k3d-cluster =
    { pkgs, lib, ... }:
    {
      resource.terraform_data =
        let
          git = lib.getExe pkgs.git;
          k3d = lib.getExe pkgs.k3d;
          podman = lib.getExe pkgs.podman;
          podmanConfig = /* sh */ ''
            if [ -z "$XDG_RUNTIME_DIR" ]; then
              XDG_RUNTIME_DIR="/run/user/$(id -u)"
            fi
            export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
            export DOCKER_SOCK="$XDG_RUNTIME_DIR/podman/podman.sock"
          '';

          # `systemctl --user enable --now podman.socket`
          cluster = "${self.gcloud.name}-local";
          registry = {
            name = "${cluster}-registry";
            port = "5001";
          };
        in
        {
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
        };
    };
}
