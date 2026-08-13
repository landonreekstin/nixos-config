# ~/nixos-config/hosts/asus-laptop/homelab.nix
{ config, pkgs, lib, ... }:

{
  customConfig.homelab = {
    nasClient.enable = true;
    localCA.trustCA = true;
  };
}
