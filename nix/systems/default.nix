{
  nixpkgs,
  pkgs,
  modulesPath,
  sops-nix,
  secrets,
  ...
}:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
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
      openssh.enable = true;
    };
    environment.systemPackages = with pkgs; [ ];
    system.stateVersion = "25.05";
  };
}
