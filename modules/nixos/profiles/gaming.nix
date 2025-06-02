# ~/nixos-config/modules/nixos/profiles/gaming.nix
{ config, pkgs, lib, ... }:

{
  # == Options ==
  # We could add options here later, e.g.:
  # options.profiles.gaming.enableSteam = lib.mkEnableOption "Enable Steam";

  # == Configuration ==
  config = lib.mkIf true { # We assume if this module is imported, gaming is enabled.
                           # Could be tied to options.profiles.gaming.enable later.

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
      
      # Games
      superTuxKart
    ];

    # Enable gaming programs
    # Allows games (especially via Lutris/Steam) to request performance optimizations
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
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
    users.users.lando.extraGroups = lib.mkMerge [
      (lib.mkIf config.users.users.lando.isNormalUser [ "video" ])
    ];
    # Note: We reference the user defined in core.nix dynamically.

  };
}
