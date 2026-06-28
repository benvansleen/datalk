{
  flake.modules.kubernetes.datalk-dev =
    { config, lib, ... }:
    let
      cfg = config.modules.datalk.dev;
    in
    {
      options.modules.datalk.dev = with lib; {
        enable = mkEnableOption "hot-reloading UI development mode";
        hostUiPath = mkOption {
          type = types.str;
          default = "/workspace/datalk/ui";
        };
      };

      config = lib.mkIf cfg.enable {
        modules.datalk.environment = lib.mkForce "development";

        applications.datalk.resources.deployments.datalk.spec.template.spec = {
          initContainers.migrate = {
            command = lib.mkForce [ "/bin/node" ];
            args = [ "/app/migrate.mjs" ];
            workingDir = "/app";
            volumeMounts = [
              {
                name = "ui-drizzle";
                mountPath = "/app/drizzle";
              }
            ];
          };

          containers.datalk = {
            command = [
              "/bin/node"
              "/app/node_modules/vite/bin/vite.js"
              "--host"
              "0.0.0.0"
            ];
            args = [
              "--port"
              "3000"
            ];
            workingDir = "/app";
            volumeMounts = [
              {
                name = "ui-src";
                mountPath = "/app/src";
              }
              {
                name = "ui-static";
                mountPath = "/app/static";
              }
              {
                name = "ui-drizzle";
                mountPath = "/app/drizzle";
              }
              {
                name = "ui-svelte-config";
                mountPath = "/app/svelte.config.js";
              }
              {
                name = "ui-vite-config";
                mountPath = "/app/vite.config.ts";
              }
              {
                name = "ui-tsconfig";
                mountPath = "/app/tsconfig.json";
              }
              {
                name = "ui-drizzle-config";
                mountPath = "/app/drizzle.config.ts";
              }
            ];

            env = [
              {
                name = "CHOKIDAR_USEPOLLING";
                value = "true";
              }
            ];
          };

          volumes = [
            {
              name = "ui-src";
              hostPath = {
                path = "${cfg.hostUiPath}/src";
                type = "Directory";
              };
            }
            {
              name = "ui-static";
              hostPath = {
                path = "${cfg.hostUiPath}/static";
                type = "Directory";
              };
            }
            {
              name = "ui-drizzle";
              hostPath = {
                path = "${cfg.hostUiPath}/drizzle";
                type = "Directory";
              };
            }
            {
              name = "ui-svelte-config";
              hostPath = {
                path = "${cfg.hostUiPath}/svelte.config.js";
                type = "File";
              };
            }
            {
              name = "ui-vite-config";
              hostPath = {
                path = "${cfg.hostUiPath}/vite.config.ts";
                type = "File";
              };
            }
            {
              name = "ui-tsconfig";
              hostPath = {
                path = "${cfg.hostUiPath}/tsconfig.json";
                type = "File";
              };
            }
            {
              name = "ui-drizzle-config";
              hostPath = {
                path = "${cfg.hostUiPath}/drizzle.config.ts";
                type = "File";
              };
            }
          ];
        };
      };
    };
}
