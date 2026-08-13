# ~/nixos-config/hosts/optiplex/homelab.nix
{ config, pkgs, lib, ... }:

{
  customConfig.homelab.localCA.trustCA = true;
}
