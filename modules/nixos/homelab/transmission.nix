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

        # Both directions are capped to keep the link to the server LAN out of
        # bufferbloat. The bottleneck is NOT the WAN (~1 Gbps): optiplex-fw
        # reaches the Spectrum router over a powerline adapter that carries
        # only ~50 Mbps. Everything behind the firewall shares it — this NAS
        # (Mullvad included), mini-server, and every WireGuard VPN client,
        # since the VPN terminates on the firewall.
        #
        # Download was originally left uncapped, relying on turtle mode being
        # flipped by hand. That failed twice: on 2026-09-04 (13 torrents at
        # ~45 Mbps, hop-1 latency 3.5 -> 133 ms) and on 2026-11-25 (one torrent
        # at ~40 Mbps; LAN pings to the router took 0.5-7 s and SSH over the
        # VPN crawled; pausing the torrent brought it back to ~3 ms).
        #
        # 20 Mbps leaves ~25-30 Mbps of the powerline for the VPN, Jellyfin
        # and mini-server. Raise or drop this if the firewall ever gets a real
        # Ethernet run to the router.
        speed-limit-down = 2500;         # 20 Mbps
        speed-limit-down-enabled = true;
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
