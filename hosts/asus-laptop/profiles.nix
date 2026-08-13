# ~/nixos-config/hosts/asus-laptop/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.fpga-ice40.enable = true;
    development.embedded-linux.enable = true;
    development.kernel.enable = false;
  };
}
