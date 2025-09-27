# ~/nixos-config/modules/nixos/profiles/gaming.nix
{ config, pkgs, lib, unstablePkgs, ... }:
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

    # 3. Merge this list into the host's unstable package list.
    #    Now, any part of the system asking for 'steam', 'lutris', etc.,
    #    will get the unstable version via the overlay.
    customConfig.packages.unstable-override = lib.mkMerge [ unstableGamingPackages ];

    # 4. Point all EXPLICIT package definitions in this module to unstablePkgs.
    environment.systemPackages = with unstablePkgs; [
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
      extraCompatPackages = with unstablePkgs; [
        proton-ge-bin
      ];
      gamescopeSession.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      remotePlay.openFirewall = true;
    };
    
    networking.firewall.allowedUDPPorts = [ 2757 2759 ];
    
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;

    # Use an unstable kernel for the latest hardware support/fixes
    #boot.kernelPackages = unstablePkgs.linuxPackages_latest;
    #boot.initrd.availableKernelModules = [ "nvme" ];

    # Gamepad Input
    hardware.xpadneo.enable = true;

    users.users.${config.customConfig.user.name}.extraGroups = lib.mkMerge [
      (lib.mkIf config.users.users.${config.customConfig.user.name}.isNormalUser [ "video" ])
    ];
    
  };
}