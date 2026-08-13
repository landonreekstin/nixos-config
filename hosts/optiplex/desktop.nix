# ~/nixos-config/hosts/optiplex/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "hyprland" "kde" ];
    displayManager = {
      enable = true; # false will go to TTY but not autolaunch a DE
      type = "ly";
      ly.theme = "century-series";
    };
    monitors = [
      {
        name = "main";
        identifier = "Dell Inc. DELL S2721HGF DZR2123";
        resolution = "1920x1080@144";
        position = "0x0";
        scale = "1";
      }
      {
        name = "left";
        identifier = "Dell Inc. OptiPlex 7760 0x36419E0A";
        resolution = "preferred";
        position = "-1080x-410";
        scale = "1";
        transform = "1";
      }
      {
        name = "right";
        identifier = "Samsung Electric Company S27R65x H4TW800293";
        resolution = "preferred";
        position = "1920x-390";
        scale = "1";
        transform = "1";
      }
      {
        name = "tv";
        identifier = "Hisense Electric Co. Ltd. 4Series43 0x00000278";
        resolution = "preferred";
        position = "0x-1080";
        scale = "1";
      }
    ];
    wayvnc = {
      enable = true;
      targetMonitor = "tv";
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
            label = "FILES";
            command = "${pkgs.cosmic-files}/bin/cosmic-files";
            tooltip = "File Manager";
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
            label = "EDIT";
            command = config.customConfig.apps.programs.editor.command;
            tooltip = "Text Editor";
          }
          {
            label = "AUDIO";
            command = config.customConfig.apps.programs.music.command;
            tooltip = "Music Player";
          }
          {
            label = "COMM";
            command = config.customConfig.apps.programs.chat.command;
            tooltip = "Communications";
          }
          {
            label = "GAME";
            command = "steam";
            tooltip = "Gaming Platform";
          }
        ];
      };
      weather = {
        location = "";        # auto-detect by IP
        useFahrenheit = true;
      };
    };
  };

  # Rotate console framebuffer for vertical native display (Ly login manager)
  # rotate:3 = 270° clockwise (90° counter-clockwise) to match physical orientation
  boot.kernelParams = [ "fbcon=rotate:3" ];
}
