# ~/nixos-config/hosts/gaming-pc/homelab.nix
{ config, pkgs, lib, ... }:

let
  vars = import ./vars.nix;
in
{
  customConfig.homelab = {
    nasClient = {
      enable = true;
      # When nasViaLanWg is true, mount the NAS via the dedicated LAN WG tunnel
      # (routes to 192.168.100.76 through wg-nas — see networking.nix). Otherwise,
      # use the legacy main-LAN address (which post-migration is an alias on the
      # fw's re0).
      serverAddress = if vars.nasViaLanWg then "192.168.100.76" else "192.168.1.76";
    };
    localCA.trustCA = true;
  };
}
