# ~/nixos-config/hosts/asus-m15/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.gbdk.enable = true;
  };
}
