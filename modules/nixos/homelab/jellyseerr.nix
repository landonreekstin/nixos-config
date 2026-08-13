# ~/nixos-config/modules/nixos/homelab/jellyseerr.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.jellyseerr;
in
{
  options.customConfig.homelab.jellyseerr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Jellyseerr, a media request manager for Jellyfin.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.jellyseerr = {
      enable = true;
      openFirewall = true;
    };

  };
}
