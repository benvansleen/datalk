{
  domain,
  port ? 3000,
}:
{
  self,
  config,
  lib,
  ...
}:

{
  imports = [
    ./default.nix
    (import ../services/ui { inherit port; })
    ../services/database.nix
  ];

  config = {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    services.nginx.virtualHosts = {
      ${domain} = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString port}";
          };
        };
      };
    };

    containers.py-sandbox = {
      autoStart = true;
      ephemeral = true;
      hostAddress = "10.250.0.1";
      localAddress = "10.250.0.2";
      privateNetwork = true;
      config =
        { pkgs, ... }:
        (lib.recursiveUpdate
          {
            system.stateVersion = config.system.stateVersion;
          }
          (
            import ../services/python-server.nix {
              inherit self pkgs;
              inherit (pkgs) lib;
            }
          )
        );
    };
  };
}
