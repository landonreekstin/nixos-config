# ~/nixos-config/hosts/asus-laptop/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" ];
    autostart = [];
    idle = {
      lockTimeout  = 900;   # 15 min (AC)
      sleepTimeout = 1200;  # 20 min (AC)
      battery = {
        lockTimeout  = 600; # 10 min
        sleepTimeout = 900; # 15 min
      };
    };
    hyprland = {
      launcher = {
        enable = true;
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
            label = "AUDIO";
            command = "flatpak run com.spotify.Client";
            tooltip = "Music Player";
          }
          {
            label = "COMM";
            command = "${pkgs.vesktop}/bin/vesktop";
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
      enable = true;
      type = "ly";
      ly = {
        theme = "century-series";
        animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
        ttyRows = 67;
        ttyCols = 240;
      };
      sddm = {
        theme = "sddm-astronaut";
        embeddedTheme = "pixel_sakura";
        screensaver = {
          enable = false;
          timeout = 1; # e.g., 10 minutes
        };
      };
    };
  };
}
