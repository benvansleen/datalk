{
  flake.modules.kubernetes.datalk-ingress =
    { config, lib, ... }:
    {
      options.modules.datalk.ingress =
        with lib;
        mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                type = mkOption {
                  type = types.enum [
                    "local"
                    "tailscale"
                  ];
                };
                host = mkOption { type = types.str; };
              };
            }
          );
          default = null;
        };

      config =
        let
          cfg = config.modules.datalk.ingress;
          ingressPath = {
            path = "/";
            pathType = "Prefix";
            backend.service = {
              name = "datalk";
              port.name = "http";
            };
          };
        in
        lib.mkIf (cfg != null) {
          applications.datalk.resources.ingresses = {
            datalk.spec = {
              rules = [
                {
                  inherit (cfg) host;
                  http.paths = [ ingressPath ];
                }
              ];
            }
            // lib.optionalAttrs (cfg.type == "tailscale") {
              ingressClassName = "tailscale";
              tls = [
                {
                  hosts = [ cfg.host ];
                }
              ];
            };
          };
        };
    };
}
