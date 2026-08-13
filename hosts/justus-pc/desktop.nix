# ~/nixos-config/hosts/justus-pc/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" ];
    displayManager = {
      enable = true; # false will go to TTY but not autolaunch a DE
      type = "sddm";
      sddm = {
        theme = "sddm-astronaut";
        embeddedTheme = "hyprland_kath";
        screensaver = {
          enable = true;
          timeout = 25; # e.g., 10 minutes
        };
      };
    };
  };
}
