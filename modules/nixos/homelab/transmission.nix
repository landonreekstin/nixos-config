# ~/nixos-config/modules/nixos/homelab/transmission.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.transmission;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  config = lib.mkIf cfg.enable {

    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      openRPCPort = true;
      settings = {
        download-dir = "${mediaCfg.storagePath}/downloads/torrents";
        incomplete-dir = "${mediaCfg.cachePath}/torrents/incomplete";
        incomplete-dir-enabled = true;
        rpc-bind-address = "0.0.0.0";
        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
        umask = 2;

        # Upload cap prevents bufferbloat from saturating the ~20 Mbps WAN uplink.
        # Download is left uncapped — turtle mode handles the gaming case.
        speed-limit-up = 1875;           # 15 Mbps
        speed-limit-up-enabled = true;

        # Turtle mode (toggle from web UI when gaming): 5 Mbps down / 3 Mbps up
        alt-speed-down = 625;
        alt-speed-up = 375;

        peer-limit-global = 80;
      };
    };

  };
}
