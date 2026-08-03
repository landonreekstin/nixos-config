# ~/nixos-config/modules/nixos/profiles/gaming.nix
{ config, pkgs, lib, ... }:
let
  unstableGamingPackages = [
    "steam"
    "lutris"
    "heroic"
    "wineWow64Packages"
    "winetricks"
    "protonup-qt"
    "mangohud"
    "gamemode"
    "gamescope"
    "vulkan-tools"
    "r2modman"
    "atlauncher"
    "supertuxkart"
    "proton-ge-bin"
    "xpadneo" # The package for the kernel module
  ];

  # gamemode start/end hook: drop xfwm4 compositing while a game runs, restore it after.
  # On the XFCE (X11) Win7 session the compositor paces composited (non-unredirected) games to a
  # vblank; with a mixed-refresh multi-monitor layout (e.g. 180Hz LG + 60Hz portrait) that
  # stutters — high fps counter, choppy feel. Disabling compositing for the game's duration
  # removes the pacing while keeping Aero glass on the desktop the rest of the time. Guarded on a
  # running xfwm4 so it's a no-op in KDE/Hyprland (and on non-XFCE gaming hosts). gamemoded's env
  # may lack the session bus, so set DBUS_SESSION_BUS_ADDRESS explicitly; xfconfd applies it live.
  gamemodeXfwmCompositor = pkgs.writeShellScript "gamemode-xfwm-compositor" ''
    export DBUS_SESSION_BUS_ADDRESS="unix:path=''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/bus"
    ${pkgs.procps}/bin/pgrep xfwm4 >/dev/null 2>&1 || exit 0
    ${pkgs.xfce.xfconf}/bin/xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s "$1" || true
  '';
in
{

  # == Configuration ==
  config = lib.mkIf config.customConfig.profiles.gaming.enable {

    environment.systemPackages = (with pkgs.unstable; [
      # Launchers / Compatibility Layers
      steam # Check prerequisites (32-bit libs, vulkan drivers - nvidia module should handle these)
      dolphin-emu
      wineWow64Packages.stable # Wine (stable branch, includes 32-bit/WoW64)
      winetricks
      protonup-qt # GUI for managing Proton-GE/Wine-GE versions

      # Performance / Overlay / Utilities
      mangohud # Performance overlay
      gamescope
      # goverlay # GUI for MangoHud config (optional)

      # Vulkan Tools (Good for diagnostics)
      vulkan-tools

      # Mod Managers
      r2modman # Lethal Company
      atlauncher # Minecraft
      
      # Games
      supertuxkart

      # Screen Recorder
      gpu-screen-recorder-gtk
    ]) ++ (with pkgs; [
      # Stable fallbacks (unstable versions have broken deps)
      lutris
      heroic
    ]);

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

    programs.gamemode = {
      enable = true;
      enableRenice = true;
      # Only wire the XFCE compositor toggle on hosts that actually run XFCE; the script is also
      # runtime-guarded on a live xfwm4, so it's doubly safe.
      settings = lib.mkIf (lib.elem "xfce" config.customConfig.desktop.environments) {
        custom = {
          start = "${gamemodeXfwmCompositor} false";
          end   = "${gamemodeXfwmCompositor} true";
        };
      };
    };
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
    # For official Nintendo or Mayflash GameCube adapter                                                                             
    services.udev.extraRules = ''                                                                                                    
      # Nintendo GameCube Controller Adapter                                                                                         
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"                   
      # Mayflash GameCube Controller Adapter                                                                                         
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="0079", ATTRS{idProduct}=="1825", MODE="0666"                   
    '';

    # Add user to required groups for gaming
    # - video: Vulkan/DRI access (may be handled by drivers/DEs, but explicit is safe)
    # - gamemode: Allows CPU governor changes without authentication prompts
    users.users.${config.customConfig.user.name}.extraGroups = lib.mkMerge [
      (lib.mkIf config.users.users.${config.customConfig.user.name}.isNormalUser [ "video" "gamemode" ])
    ];
    # Note: We reference the user defined in core.nix dynamically.

  };
}
