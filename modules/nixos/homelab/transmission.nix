# ~/nixos-config/modules/nixos/homelab/transmission.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.transmission;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  options.customConfig.homelab.transmission = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Transmission, a lightweight torrent client.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      openRPCPort = true;
      settings = {
        download-dir = "${mediaCfg.storagePath}/downloads/torrents";

        # Stage in-flight downloads on the storage HDD, NOT the cache SSD.
        #
        # cachePath is a btrfs subvolume on the same 238G device as / and /nix,
        # and Transmission enforces no headroom there. On 2026-08-30 five large
        # remuxes in flight at once put 177G in the incomplete dir, filled the
        # device to 100%, and took the whole machine down with it: transmission
        # SEGV'd, nix-serve 500'd on every request (it could not reach the nix
        # daemon) and Jellyfin had no room to transcode. Nothing could complete,
        # so nothing ever drained to storagePath — a deadlock, not a transient.
        #
        # Keeping incomplete on storagePath also makes completion a same-
        # filesystem rename into download-dir instead of a cross-device copy.
        incomplete-dir = "${mediaCfg.storagePath}/downloads/incomplete";
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
