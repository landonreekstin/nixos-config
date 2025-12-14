# ~/nixos-config/modules/nixos/profiles/gaming.nix
{ config, pkgs, lib, ... }:
let
  unstableGamingPackages = [
    "steam"
    "lutris"
    "heroic"
    "wineWowPackages" # Note: wineWowPackages is an attr set, but the overlay will replace the top-level name
    "winetricks"
    "protonup-qt"
    "mangohud"
    "gamemode"
    "gamescope"
    "vulkan-tools"
    "r2modman"
    "atlauncher"
    "superTuxKart"
    "proton-ge-bin"
    "xpadneo" # The package for the kernel module
  ];
in 
{

  # == Configuration ==
  config = lib.mkIf config.customConfig.profiles.gaming.enable {

    environment.systemPackages = with pkgs.unstable; [
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

      # Screen Recorder
      gpu-screen-recorder-gtk
    ];

    programs.gpu-screen-recorder.enable = true;

    programs.steam = {
      enable = true;
      package = pkgs.unstable.steam;
      extraCompatPackages = with pkgs.unstable; [
        proton-ge-bin
      ];
      gamescopeSession.enable = true;
      localNetworkGameTransfers.openFirewall = true; # Allow local network game transfers
      remotePlay.openFirewall = true; # Allow remote play connections
    };
    networking.firewall.allowedUDPPorts = [ 2757 2759 ]; # SuperTuxKarts networking ports
    
    programs.gamemode.enable = true;
    programs.gamescope = {
      enable = true;
      package = pkgs.unstable.gamescope;
    };
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

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
