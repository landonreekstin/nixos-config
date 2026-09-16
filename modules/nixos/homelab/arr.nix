# ~/nixos-config/modules/nixos/homelab/arr.nix
{ config, lib, ... }:

let
  arrCfg = config.customConfig.homelab.arr;
in
{
  options.customConfig.homelab.arr = with lib; {
    prowlarr = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Prowlarr
        description = "Enable Prowlarr, an indexer manager for Radarr and Sonarr.";
      };
    };
    radarr = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Radarr
        description = "Enable Radarr, a movie collection manager.";
      };
    };
    sonarr = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Sonarr
        description = "Enable Sonarr, a TV series collection manager.";
      };
    };
    bazarr = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Bazarr
        description = "Enable Bazarr, a subtitle manager for Radarr and Sonarr.";
      };
    };
    lidarr = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for Lidarr
        description = "Enable Lidarr, a music collection manager.";
      };
    };
  };

  config = lib.mkMerge [

    (lib.mkIf arrCfg.prowlarr.enable {
      services.prowlarr = {
        enable = true;
        openFirewall = true;
      };
      users.users.prowlarr = {
        isSystemUser = true;
        group = "prowlarr";
      };
      users.groups.prowlarr = {};
    })

    (lib.mkIf arrCfg.radarr.enable {
      services.radarr = {
        enable = true;
        openFirewall = true;
      };
      # Radarr creates each title directory. At the default 0022 the group write
      # bit is dropped, so Bazarr - though it is in the media group - cannot write
      # .srt sidecars next to the video. 0002 keeps the media group writable.
      systemd.services.radarr.serviceConfig.UMask = "0002";
    })

    (lib.mkIf arrCfg.sonarr.enable {
      services.sonarr = {
        enable = true;
        openFirewall = true;
      };
      # Same as Radarr: keep series directories group-writable for Bazarr.
      systemd.services.sonarr.serviceConfig.UMask = "0002";
    })

    (lib.mkIf arrCfg.bazarr.enable {
      services.bazarr = {
        enable = true;
        openFirewall = true;
      };
      # Subtitles Bazarr writes must stay group-writable so media-linker can
      # hardlink them into the per-user libraries.
      systemd.services.bazarr.serviceConfig.UMask = "0002";
    })

    (lib.mkIf arrCfg.lidarr.enable {
      services.lidarr = {
        enable = true;
        openFirewall = true;
      };
      # Same as Radarr/Sonarr: Lidarr creates the artist/album directories, and at
      # the default 0022 the group write bit is dropped. 0002 keeps them writable
      # by the media group, which is what lets soularr hand imports over and lets
      # Navidrome/Jellyfin read the result.
      systemd.services.lidarr.serviceConfig.UMask = "0002";
    })

  ];
}
