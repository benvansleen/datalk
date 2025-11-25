{
  nixpkgs,
  pkgs,
  modulesPath,
  extra-container,
  sops-nix,
  secrets,
  ...
}:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    extra-container.nixosModules.default
    sops-nix.nixosModules.sops
  ];

  config = {
    sops = secrets.system "/etc/ssh/ssh_host_ed25519_key";
    nix = {
      channel.enable = false;
      registry.nixpkgs.flake = nixpkgs;
      gc.automatic = false;
      settings = {
        accept-flake-config = true;
        auto-optimise-store = true;
        cores = 0;
        connect-timeout = 5;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        fallback = true;
        min-free = 128000000; # 128 MB
        trusted-users = [ "@wheel" ];
      };
    };
    nixpkgs.hostPlatform = {
      system = "x86_64-linux";
    };
    services = {
      fail2ban.enable = true;
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
    environment.systemPackages = with pkgs; [ ];
    programs.extra-container.enable = true;

    system.stateVersion = "25.05";
  };
}
