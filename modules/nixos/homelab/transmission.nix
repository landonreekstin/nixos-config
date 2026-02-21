# ~/nixos-config/modules/nixos/homelab/transmission.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.transmission;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  config = lib.mkIf cfg.enable {

    services.transmission = {
      enable = true;
      openRPCPort = true;
      settings = {
        download-dir = "${mediaCfg.storagePath}/downloads/torrents";
        incomplete-dir = "${mediaCfg.cachePath}/torrents/incomplete";
        incomplete-dir-enabled = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
        umask = 2;
      };
    };

  };
}
