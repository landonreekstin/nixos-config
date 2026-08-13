# ~/nixos-config/hosts/justus-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
  };
}
