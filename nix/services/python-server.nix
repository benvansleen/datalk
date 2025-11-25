{
  self,
  pkgs,
  lib,
  ...
}:

## ALWAYS RUN WITHIN CONTAINER
{
  systemd.services.python-server = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.python-server;
      Restart = "always";
      User = "python-server";
    };
  };

  users.users.python-server = {
    isNormalUser = true;
  };

  networking.firewall.allowedTCPPorts = [
    8000
  ];
}
