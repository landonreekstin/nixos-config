# ~/nixos-config/hosts/atl-mini-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    nvidia = {
      enable = false;
    };
  };

  services.xserver.videoDrivers = [ "i810" ];
}
