# ~/nixos-config/hosts/mini-server/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = false;
    development.kernel.enable = false;
    development.fpga-ice40.enable = false;
  };
}
