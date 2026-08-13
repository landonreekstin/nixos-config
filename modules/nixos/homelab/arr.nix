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
    })

    (lib.mkIf arrCfg.sonarr.enable {
      services.sonarr = {
        enable = true;
        openFirewall = true;
      };
    })

    (lib.mkIf arrCfg.bazarr.enable {
      services.bazarr = {
        enable = true;
        openFirewall = true;
      };
    })

  ];
}
