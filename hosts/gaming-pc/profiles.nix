# ~/nixos-config/hosts/gaming-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development = {
      fpga-ice40.enable = true;
      kernel.enable = true;
      embedded-linux.enable = true;
      gbdk.enable = true;
      cpp-practice.enable = true;
    };
  };
}
