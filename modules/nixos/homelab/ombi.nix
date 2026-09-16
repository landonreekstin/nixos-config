# ~/nixos-config/modules/nixos/homelab/ombi.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.ombi;
in
{
  options.customConfig.homelab.ombi = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Ombi, the request portal for music. Jellyseerr - which handles
        film and TV requests here - has no music support at all, and Ombi is the
        only packaged request frontend that drives Lidarr. Its Jellyfin server,
        user import and Lidarr connection are configured once through its web UI;
        see docs/music.md.
      '';
    };

    port = mkOption {
      type = types.port;
      # NOT Ombi's upstream default of 5000: nix-serve already has that port on
      # this host (homelab/nix-cache.nix).
      default = 5010;
      description = "Port for the Ombi web interface. Fronted by nginx as ombi.lan.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.ombi = {
      enable = true;
      port = cfg.port;
      openFirewall = true;
    };

  };
}
