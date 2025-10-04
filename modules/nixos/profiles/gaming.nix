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
      steam
      lutris
      heroic
      wineWowPackages.stable
      winetricks
      protonup-qt

      # Performance / Overlay / Utilities
      mangohud
      gamemode
      gamescope

      # Vulkan Tools
      vulkan-tools

      # Mod Managers
      r2modman
      atlauncher
      
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
      localNetworkGameTransfers.openFirewall = true;
      remotePlay.openFirewall = true;
    };
    
    networking.firewall.allowedUDPPorts = [ 2757 2759 ];
    
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

    users.users.${config.customConfig.user.name}.extraGroups = lib.mkMerge [
      (lib.mkIf config.users.users.${config.customConfig.user.name}.isNormalUser [ "video" ])
    ];
    
  };
}