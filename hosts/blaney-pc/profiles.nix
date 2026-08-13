# ~/nixos-config/hosts/blaney-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.gbdk.enable = true;
  };
}
