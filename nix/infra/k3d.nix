{
  flake = {
    local-image-uri = img: "k3d-datalk-local-registry:5000/${img.imageName}:local";
    local-image-push-uri = img: "localhost:5001/${img.imageName}:local";

    modules.infra.k3d =
      { pkgs, lib, ... }:
      {
        terraform.required_providers.null = {
          source = "hashicorp/null";
          version = "~> 3.2";
        };

        resource.null_resource =
          let
            k3d = lib.getExe pkgs.k3d;
            podman = lib.getExe pkgs.podman;
            # `systemctl --user enable --now podman.socket`
            podmanConfig = /* sh */ ''
              if [ -z "$XDG_RUNTIME_DIR" ]; then
                XDG_RUNTIME_DIR="/run/user/$(id -u)"
              fi
              export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
              export DOCKER_SOCK="$XDG_RUNTIME_DIR/podman/podman.sock"
            '';
            cluster = "datalk-local";
            registry = {
              name = "datalk-local-registry";
              port = "5001";
            };
            k3dConfig = (pkgs.formats.yaml { }).generate "k3d-datalk-local.yaml" {
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
                      arg = "--disable=traefik";
                      nodeFilters = [ "server:*" ];
                    }
                    {
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
            k3d_cluster = {
              triggers = {
                cluster_name = cluster;
              };

              provisioner.local-exec = [
                {
                  command = /* sh */ ''
                    ${podmanConfig}
                    if ${k3d} cluster list ${cluster} >/dev/null 2>&1; then
                      echo "k3d cluster ${cluster} already exists"
                    else
                      ${k3d} cluster create \
                        --config ${k3dConfig} \
                        --network ${cluster} \
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
                "null_resource.k3d_registry"
              ];
            };

            k3d_registry = {
              triggers = {
                registry_name = registry.name;
                host_port = registry.port;
              };
              depends_on = [
                "null_resource.k3d_network"
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
              triggers = {
                network_name = cluster;
              };

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
  };
}
