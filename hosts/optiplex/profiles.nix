# ~/nixos-config/hosts/optiplex/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.fpga-ice40.enable = false;
    development.kernel.enable = false;
  };
}
