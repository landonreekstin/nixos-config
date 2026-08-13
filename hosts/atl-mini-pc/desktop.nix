# ~/nixos-config/hosts/atl-mini-pc/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" ];
    kde.kwallet.enable = true;
    displayManager = {
      enable = true; # false will go to TTY but not autolaunch a DE
      type = "sddm";
    };
  };
}
