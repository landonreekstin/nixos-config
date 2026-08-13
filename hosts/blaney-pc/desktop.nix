# ~/nixos-config/hosts/blaney-pc/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" "xfce" ];
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
