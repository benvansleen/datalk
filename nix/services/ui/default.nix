{
  port ? 3000,
  self-sign-certs ? false,
}:
{
  self,
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkIf;
in
{
  config = {
    systemd.services.ui = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.ui}/bin/ui";
        Restart = "always";
        EnvironmentFile = config.sops.templates."ui.env".path;
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

    sops.templates."ui.env".content = /* ini */ ''
      PORT=${toString port}
      DB_HOST=datalk.vansleen.dev
      DB_PORT=${toString config.services.postgresql.settings.port}
      DB_USER=postgres
      DB_PASSWORD=${config.sops.placeholder.pg_password}
      DB_NAME=datalk
    '';
  };
}
