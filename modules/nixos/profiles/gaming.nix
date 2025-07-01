# ~/nixos-config/modules/nixos/profiles/gaming.nix
{ config, pkgs, lib, ... }:

{

  # == Configuration ==
  config = lib.mkIf config.customConfig.profiles.gaming.enable {

    # 1. Add Core Gaming Packages
    environment.systemPackages = with pkgs; [
      # Launchers / Compatibility Layers
      steam # Check prerequisites (32-bit libs, vulkan drivers - nvidia module should handle these)
      lutris
      heroic
      wineWowPackages.stable # Wine (stable branch, includes 32-bit/WoW64)
      winetricks
      protonup-qt # GUI for managing Proton-GE/Wine-GE versions

      # Performance / Overlay / Utilities
      mangohud # Performance overlay
      gamemode # Performance optimization daemon
      gamescope 
      # goverlay # GUI for MangoHud config (optional)

      # Vulkan Tools (Good for diagnostics)
      vulkan-tools

      # Mod Managers
      r2modman # Lethal Company
      atlauncher # Minecraft
      
      # Games
      superTuxKart
    ];

    # Enable gaming programs
    # Allows games (especially via Lutris/Steam) to request performance optimizations
    programs.steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        # Add any additional compatibility packages needed by Steam
        proton-ge-bin
      ];
      gamescopeSession.enable = true;
      localNetworkGameTransfers.openFirewall = true; # Allow local network game transfers
      remotePlay.openFirewall = true; # Allow remote play connections
    };
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    # Enable 32-bit libraries (often needed by Steam/Wine/games)
    # Note: The Nvidia module might already enable this, but being explicit is fine.
    hardware.graphics.enable = true; # Ensure base OpenGL is set up
    hardware.graphics.enable32Bit = true;

    # Configure Kernel
    # boot.kernelPackages = pkgs.linuxPackages_latest; # Example: Using Nixpkgs latest stable
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # Gamepad Input
    hardware.xpadneo.enable = true;

    # Add user to 'video' group (often needed for Vulkan/DRI access)
    # This might be handled automatically by driver modules/DEs, but explicit is safe.
    users.users.${config.customConfig.user.name}.extraGroups = lib.mkMerge [
      (lib.mkIf config.users.users.${config.customConfig.user.name}.isNormalUser [ "video" ])
    ];
    # Note: We reference the user defined in core.nix dynamically.

  };
}
