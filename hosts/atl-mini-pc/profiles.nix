# ~/nixos-config/hosts/atl-mini-pc/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = false;
  };
}
