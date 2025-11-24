{
  port ? 3000,
  self-sign-certs ? false,
}:
{
  self,
  config ? null,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkIf;
  if-nixos-config = key: if !self-sign-certs then key else null;
in
{
  systemd.services.ui = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.ui}/bin/ui";
      Restart = "always";
      User = "ui";
      ${if-nixos-config "EnvironmentFile"} = config.sops.templates."ui.env".path;
    };
  };
  users.users.ui = {
    isNormalUser = true;
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

  ${if-nixos-config "sops"} = {
    templates."ui.env".content = /* ini */ ''
      ENVIRONMENT=production

      PORT=${toString port}
      DB_HOST=datalk.vansleen.dev
      DB_PORT=${toString config.services.postgresql.settings.port}
      DB_USER=postgres
      DB_PASSWORD=${config.sops.placeholder.pg_password}
      DB_NAME=datalk

      BETTER_AUTH_SECRET=${config.sops.placeholder.better_auth_secret}

      OPENAI_API_KEY=${config.sops.placeholder.openai_api_key}
    '';
  };
}
