# ~/nixos-config/hosts/vm-sandbox/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = false; # keep the VM light — not testing the gaming stack here
  };
}
