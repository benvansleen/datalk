{
  flake.modules.kubernetes.celld-dev =
    { config, lib, ... }:
    {
      options.modules.celld.dev = with lib; {
        enable = mkEnableOption "hot-reloading celld development mode";
        hostAppPath = mkOption {
          type = types.str;
          default = "/workspace/datalk/celld";
        };
      };

      config =
        let
          cfg = config.modules.celld.dev;
          deploymentEnv = config.modules.celld.deploymentEnv;
          deployWithEsbuild = deploymentEnv ++ [
            {
              name = "CELLD_ESBUILD";
              value = "/tools/node_modules/.bin/esbuild";
            }
          ];
        in
        lib.mkIf cfg.enable {
          applications.celld.resources.deployments.celld.spec.strategy.type = "Recreate";
          applications.celld.resources.deployments.celld.spec.template.spec = {
            shareProcessNamespace = true;
            initContainers = {
              "10-install-esbuild" = {
                image = "node:22-alpine";
                command = [
                  "sh"
                  "-c"
                  "npm install --prefix /tools esbuild"
                ];
                volumeMounts = [
                  {
                    name = "tools";
                    mountPath = "/tools";
                  }
                ];
              };
              "20-deploy-worker" = lib.mkForce {
                image = config.modules.celld.image;
                command = [
                  "celld"
                  "deploy"
                  "/app"
                  "--bucket"
                  "s3://datalk-celld"
                  "--endpoint"
                  "http://seaweedfs-s3:8333"
                  "--region"
                  "us-east-1"
                ];
                env = lib.mkForce deployWithEsbuild;
                volumeMounts = lib.mkForce [
                  {
                    name = "celld-app";
                    mountPath = "/app";
                  }
                  {
                    name = "tools";
                    mountPath = "/tools";
                  }
                ];
              };
            };
            containers = {
              celld = {
                imagePullPolicy = lib.mkForce "IfNotPresent";
                command = [ "/bin/celld-supervisor" ];
                env = [
                  {
                    name = "CELLD_CONTROL_DIR";
                    value = "/control";
                  }
                ];
                readinessProbe = lib.mkForce null;
                volumeMounts = [
                  {
                    name = "celld-app";
                    mountPath = "/app";
                  }
                  {
                    name = "celld-control";
                    mountPath = "/control";
                  }
                ];
              };
              worker-watcher = {
                image = config.modules.celld.image;
                command = [
                  "watchexec"
                  "--watch"
                  "/app/src"
                  "--watch"
                  "/app/wrangler.jsonc"
                  "--debounce"
                  "500ms"
                  "--on-busy-update=queue"
                  "--postpone"
                  "--shell=none"
                  "--"
                  "bash"
                  "-c"
                  "celld deploy /app --bucket s3://datalk-celld --endpoint http://seaweedfs-s3:8333 --region us-east-1 && kill -USR1 \"$(cat /control/supervisor.pid)\""
                ];
                env = deployWithEsbuild;
                volumeMounts = [
                  {
                    name = "celld-app";
                    mountPath = "/app";
                  }
                  {
                    name = "celld-control";
                    mountPath = "/control";
                  }
                  {
                    name = "tools";
                    mountPath = "/tools";
                  }
                ];
              };
            };
            volumes = {
              celld-app.hostPath = {
                path = cfg.hostAppPath;
                type = "Directory";
              };
              celld-control.emptyDir = { };
              tools.emptyDir = { };
            };
          };
        };
    };
}
