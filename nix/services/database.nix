{ config, ... }:

{
  networking.firewall.allowedTCPPorts = [ 5432 ];
  services.postgresql = {
    enable = true;
    enableJIT = true;
    ensureUsers = [ { name = "postgres"; } ];
    ensureDatabases = [ "datalk" ];
    enableTCPIP = true;
    settings = {
      port = 5432;
    };
    initialScript = config.sops.templates."init-sql-script".path;
    authentication = ''
      host all all 0.0.0.0/0 md5
    '';
  };

  services.redis.servers."cache" = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;
    requirePassFile = config.sops.secrets.redis_password.path;
    openFirewall = false;
  };

  sops.templates."init-sql-script" = {
    owner = "postgres";
    content = /* sql */ ''
      ALTER USER postgres WITH PASSWORD '${config.sops.placeholder.pg_password}'
    '';
  };
}
