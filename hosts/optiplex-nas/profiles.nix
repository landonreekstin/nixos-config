# ~/nixos-config/hosts/optiplex-nas/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = false;
    development.fpga-ice40.enable = false;
    development.kernel.enable = false;
  };
}
