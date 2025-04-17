# ~/nixos-config/modules/nixos/core.nix
{ config, pkgs, lib, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Nix settings (caches are defined here now)
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      # Define caches - these will be used by any host importing this module
      substituters = [
        "https://cache.nixos.org/"
        "https://cosmic.cachix.org/" # Keep cosmic cache for cosmic module
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Timezone & Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8"; LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8"; LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8"; LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8"; LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Base user account definition
  users.users.lando = {
    isNormalUser = true;
    description = "lando";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keyFiles = [
      # Consider managing keys via home-manager or secrets management later
      # For now, ensure the path is correct relative to the build environment,
      # or use an absolute path if the key file is outside the config repo.
      # Example: "/home/lando/.ssh/authorized_keys" # This requires the file to exist pre-build
    ];
    # Base packages for the user (can be overridden/extended by profiles/home-manager)
    packages = with pkgs; [
      fastfetch
      git
    ];
  };

  # Basic console settings
  console.keyMap = "us";

  # Basic system packages (can be extended by profiles)
  environment.systemPackages = with pkgs; [
    vim
    wget
    firefox
    kitty # Good base terminal
    htop
    pavucontrol # Useful audio tool
  ];

  # Power management (disable suspend)
  services.logind.extraConfig = ''
    IdleAction=ignore
    IdleActionSec=0
  '';
}
