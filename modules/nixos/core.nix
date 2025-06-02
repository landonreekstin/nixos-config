# ~/nixos-config/modules/nixos/core.nix
{ config, pkgs, lib, inputs, ... }: # `config` here is the final NixOS config, so `config.customConfig` is available

{
  # === Universal settings for all hosts ===
  
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };

  # Universal Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Caches can be universal if all hosts benefit from them
    substituters = [
      "https://cache.nixos.org/"
      "https://cosmic.cachix.org/" # If COSMIC is an option for any machine
      # Add other common caches, e.g., nix-community
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  # Universal GC settings from customConfig (or could be hardcoded if truly universal)
  nix.gc = {
    automatic = config.customConfig.nix.gc.automatic; # Driven by option
    dates = "weekly"; # Could be an option
    options = "--delete-older-than 7d"; # Could be an option
  };
  # Universal auto-optimise-store from customConfig
  nix.settings.auto-optimise-store = config.customConfig.nix.optimiseStore; # Driven by option

  # Universal console keymap
  console.keyMap = "us";

  # Universal security & logind tweaks (if they apply to all your systems)
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';
  services.logind.extraConfig = ''
    IdleAction=ignore
    IdleActionSec=0
  '';

  # === Settings Driven by `customConfig` ===
  networking.hostName = config.customConfig.system.hostName;
  time.timeZone = config.customConfig.system.timeZone;
  i18n.defaultLocale = config.customConfig.system.locale;
  i18n.extraLocaleSettings = lib.mkIf (config.customConfig.system.locale == "en_US.UTF-8") { # Example conditional extra settings
    LC_ADDRESS = "en_US.UTF-8"; LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8"; LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8"; LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8"; LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  }; # Add more locales or make this more generic if needed.

  users.users.${config.customConfig.user.name} = {
    isNormalUser = true;
    description = config.customConfig.user.name;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ]; # Common groups, can be an option
    openssh.authorizedKeys.keys = lib.mkIf (config.customConfig.services.ssh.enable) [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP2HwEWfiXzoAxXnMiP9FLZAbOgcdxhTtcWtxYxooNEQ"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILMzC5MBalzHuf4Bzd29KuvfaPSR91s7X+xg1OhZjnnu"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkJdzUE5PWC2OPoGlKTMMRmf0ntDEgoppByYWb//deT"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJixKs6/A0swM2lkEuYacWtWNHRNio/X81y28S2CIkgj"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDGIZ8pt4roFMBMGZCVOHcb3uibaREhOzSyGpL3AJ32"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiUu/xNgEdcsIuaLekWDzty1JGyk2Asy7eqnbriPkmE"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAHx/cuuV/hFddQhYcoTGLWfbxbNfMPBYzkmD5cnriFM"
    ];
    shell = config.customConfig.user.shell; # Driven by option
    home = config.customConfig.user.home;   # Driven by option
    # Base user packages are now handled by customConfig.packages.homeManager
    # packages = []; # System-level packages for user are less common with Home Manager
  };

  # Base system packages (driven by customConfig, plus any truly universal ones)
  environment.systemPackages = with pkgs; [
    git # Example of a truly universal package for all systems
    # Add other universal CLI tools if any
    fastfetch
  ] ++ config.customConfig.packages.nixos; # Appends host-specific system packages

  # nix-ld (driven by customConfig)
  programs.nix-ld = lib.mkIf config.customConfig.nix.nix-ld.enable {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      # Add other globally useful libs for nix-ld
    ];
  };

  # Placeholder for where other conditional modules would be configured
  # For example, if you had a `bluetooth.nix` module:
  # services.blueman.enable = lib.mkIf config.customConfig.hardware.bluetooth.enable true;
}