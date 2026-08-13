# ~/nixos-config/hosts/asus-m15/desktop.nix
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
            command = config.customConfig.apps.programs.browserAlt.command;
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
      enable = true;
      # HTPC auto-login requires SDDM (Ly does not support autoLogin/defaultSession).
      # Previous Ly F-15 login is preserved below — swap back if not running HTPC mode.
      type = "sddm";
      # ly = {
      #   theme = "century-series";
      #   animationFile = ../../assets/ly/f15-animation-240x67.dur; # 1080p: 240x67 chars
      #   ttyRows = 67;
      #   ttyCols = 240;
      # };
      # sddm = {
      #   theme = "sddm-astronaut";
      #   customTheme = {
      #     enable = true;
      #     wallpaper = ../../assets/wallpapers/spooky-sddm.mp4;
      #     blur = 2.0;
      #     roundCorners = 20;
      #     colors = {
      #       formBackground = "#1e1e2e";
      #       dimBackground = "#1e1e2e";
      #       headerText = "#cdd6f4";
      #       dateText = "#cdd6f4";
      #       timeText = "#cdd6f4";
      #       placeholderText = "#a6adc8";
      #       loginButtonBackground = "#89b4fa";
      #       loginButtonText = "#1e1e2e";
      #       highlightBackground = "#89b4fa";
      #       systemButtonsIcons = "#cdd6f4";
      #     };
      #   };
      #   screensaver = {
      #     enable = false;
      #   };
      # };
    };
  };
}
