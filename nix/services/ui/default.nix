{
  port ? 3000,
  self-sign-certs ? false,
}:
{
  self,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkIf;
in
{
  systemd.services.ui = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.ui}/bin/ui";
      Restart = "always";
      Environment = "PORT=${toString port}";
    };
  };
  users.users.nginx.extraGroups = [ "acme" ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "benvansleen@gmail.com";
  };
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      localhost = {
        forceSSL = self-sign-certs;
        sslCertificate = mkIf self-sign-certs ./self-signed-certs/localhost.crt;
        sslCertificateKey = mkIf self-sign-certs ./self-signed-certs/localhost.key;
        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString port}";
          };
        };
      };
    };
  };
}
