{
  domain,
  port ? 3000,
}:
{ ... }:

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
  };
}
