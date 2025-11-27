{
  self,
  pkgs,
  lib,
  ...
}:

## ALWAYS RUN WITHIN CONTAINER
{
  systemd.services.py-sandbox = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.python-server;
      Restart = "always";
      User = "py-sandbox";
      WorkingDirectory = "/home/py-sandbox";
    };
  };

  users.users.py-sandbox = {
    isNormalUser = true;
  };

  networking.firewall.allowedTCPPorts = [
    8000
  ];
}
