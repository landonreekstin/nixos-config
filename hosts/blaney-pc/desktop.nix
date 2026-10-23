# ~/nixos-config/hosts/blaney-pc/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" "xfce" ];
    # Sceptre sits directly below the Acer, centred under it. `edid` is what the XFCE
    # resolver matches on (X11 connector names move around); `identifier` is Hyprland's.
    monitors = [
      {
        name = "main";
        identifier = "DP-1";
        edid = "KB272";
        resolution = "1920x1080@60";
        position = "0x0";
      }
      {
        name = "below";
        identifier = "HDMI-A-1";
        edid = "E205W-1600";
        resolution = "1600x900@60";
        position = "160x1080";
      }
    ];
    hyprland = {
      # His Hyprland desktop is glade (hyprland.desktops in home.nix), whose
      # name boards open his apps, so the bottom launcher bar is off; the pins below are
      # kept for if it is ever turned back on.
      launcher = {
        enable = false;
        pinnedApps = [
          {
            label = "TERM";
            command = config.customConfig.apps.programs.terminal.command;
            tooltip = "Terminal Emulator";
          }
          {
            label = "NAV";
            command = config.customConfig.apps.programs.browser.command;
            tooltip = "Web Browser";
          }
          {
            label = "CODE";
            command = config.customConfig.apps.programs.ide.command;
            tooltip = "IDE";
          }
          {
            label = "COMM";
            command = "flatpak run com.discordapp.Discord";
            tooltip = "Communications";
          }
          {
            label = "GAME";
            command = "steam";
            tooltip = "Gaming Platform";
          }
        ];
      };
    };
    displayManager = {
      enable = true; # false will go to TTY but not autolaunch a DE
      type = "ly";
      ly = {
        theme = "century-series";
        animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
        ttyRows = 67;
        ttyCols = 240;
      };
    };
  };
}
