# ~/nixos-config/modules/nixos/common/bootloader.nix
{ config, pkgs, lib, ... }:
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };
}