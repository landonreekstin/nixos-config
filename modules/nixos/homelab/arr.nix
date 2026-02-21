# ~/nixos-config/modules/nixos/homelab/arr.nix
{ config, lib, ... }:

let
  arrCfg = config.customConfig.homelab.arr;
in
{
  config = lib.mkMerge [

    (lib.mkIf arrCfg.prowlarr.enable {
      services.prowlarr = {
        enable = true;
        openFirewall = true;
      };
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
