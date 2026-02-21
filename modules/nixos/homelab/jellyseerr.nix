# ~/nixos-config/modules/nixos/homelab/jellyseerr.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.jellyseerr;
in
{
  config = lib.mkIf cfg.enable {

    services.jellyseerr = {
      enable = true;
      openFirewall = true;
    };

  };
}
