# ~/nixos-config/modules/nixos/homelab/flaresolverr.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.flaresolverr;
in
{
  config = lib.mkIf cfg.enable {

    services.flaresolverr = {
      enable = true;
      openFirewall = true;
    };

  };
}
