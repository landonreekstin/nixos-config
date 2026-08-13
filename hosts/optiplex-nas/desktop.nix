# ~/nixos-config/hosts/optiplex-nas/desktop.nix
{ config, pkgs, lib, ... }:

{
  # This is a server, so we disable the desktop environment.
  customConfig.desktop = {
    environments =  [ "none" ];
    displayManager = {
      enable = false;
      type = "none";
    };
  };
}
