# ~/nixos-config/modules/nixos/homelab/qbittorrent.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.qbittorrent;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  options.customConfig.homelab.qbittorrent = with lib; {
    enable = mkEnableOption ''
      qBittorrent, a second torrent client alongside Transmission.

      This exists for Gamarr, which is qBittorrent-only on the import side:
      its TransmissionClient implements AddTorrent but nothing ever calls
      GetTorrents, so a Transmission grab is started and then never detected
      as complete, never imported and never organised. Both watchGameTorrent
      and the orphan watcher poll qBit exclusively (this is still true on
      upstream main, not just the pinned release).

      Transmission stays the client for the media stack; nothing moves.
    '';

    webPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for the qBittorrent Web UI.";
    };

    torrentPort = mkOption {
      type = types.port;
      # Transmission has 51413; these two must not collide.
      default = 51414;
      description = "Incoming BitTorrent peer port.";
    };

    downloadDir = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/downloads/torrents/gamarr";
      defaultText = literalExpression ''"''${storagePath}/downloads/torrents/gamarr"'';
      description = ''
        Default save path. Shares the storage pool with the library so Gamarr's
        hardlink imports stay on one filesystem.
      '';
    };

    incompleteDir = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/downloads/incomplete-qbt";
      defaultText = literalExpression ''"''${storagePath}/downloads/incomplete-qbt"'';
      description = ''
        Where in-flight torrents stage. On storagePath, NOT cachePath - see the
        long note in homelab/transmission.nix about the 2026-08-30 outage where
        in-flight downloads filled the 238G cache device and deadlocked the host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.qbittorrent = {
      enable = true;
      webuiPort = cfg.webPort;
      torrentingPort = cfg.torrentPort;
      openFirewall = true;

      serverConfig = {
        Preferences = {
          WebUI = {
            # Gamarr talks to this over loopback and, in the pinned release, can
            # only do cookie auth with a username and password. Whitelisting
            # loopback lets it connect without a credential to store.
            #
            # Note nginx proxies from 127.0.0.1, so LAN traffic through
            # qbittorrent.lan is whitelisted too. That matches transmission.lan,
            # which already runs with rpc auth disabled - the LAN is the trust
            # boundary here, not the individual service.
            AuthSubnetWhitelistEnabled = true;
            AuthSubnetWhitelist = "127.0.0.1/32";
          };
        };

        BitTorrent.Session = {
          DefaultSavePath = cfg.downloadDir;
          TempPathEnabled = true;
          TempPath = cfg.incompleteDir;

          # Upload cap, same reasoning as transmission.nix: the WAN uplink is
          # ~20 Mbps and bufferbloat from a saturated uplink is felt everywhere.
          # Two clients seed concurrently now, so this is deliberately well under
          # Transmission's 15 Mbps rather than a second full-rate uploader.
          GlobalMaxUploadSpeed = 625;   # 5 Mbps, in KiB/s
        };
      };
    };

    # Gamarr hardlinks out of the completed directory, which means it must be
    # able to read what qBittorrent wrote. The module sets no umask, so the
    # default 0022 would drop group-write and leave the media group locked out
    # of the category dirs qBittorrent creates - same failure Radarr had.
    systemd.services.qbittorrent.serviceConfig.UMask = "0002";
  };
}
