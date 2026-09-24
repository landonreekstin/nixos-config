# ~/nixos-config/hosts/optiplex-nas/homelab.nix
{ config, pkgs, lib, ... }:

{
  customConfig.homelab = {
    samba = {
      enable = true; # This keeps your original share active
      private = {
        enable = true; # This activates the new private share
        # The path defaults to /mnt/private, which is correct for this host.
        # The port defaults to 4445.
      };
    };
    jellyfin = {
      enable = true;
      hwTranscoding = true;
    };
    mediaSetup = {
      enable = true;
      user = config.customConfig.user.name; # This pulls "lando" from the user section
      storagePath = "/mnt/storage";
      cachePath = "/mnt/cache";
    };
    arr = {
      prowlarr.enable = true;
      radarr.enable = true;
      sonarr.enable = true;
      bazarr.enable = true;
      # Converge Bazarr's settings + English language profile over its REST API.
      # Bazarr rewrites config.yaml and its DB at runtime, so this is the only way
      # to keep it declarative. credentialsFile points at the sops secret below.
      bazarr.provision.enable = true;
      bazarr.provision.credentialsFile =
        config.sops.secrets."opensubtitles-credentials".path;
      lidarr.enable = true;
      # Converge the music root folder and the Transmission download client over
      # Lidarr's REST API, same reasoning as the Bazarr provisioner above.
      lidarr.provision.enable = true;
    };
    transmission.enable = true;

    # ── Music stack ──────────────────────────────────────────────────────────
    # Jellyseerr handles film/TV requests but has no music support whatsoever,
    # so music gets its own request portal (Ombi) and its own player
    # (Navidrome). Both read the one shared library Lidarr fills; Jellyfin also
    # has a Music library pointed at the same directory.
    navidrome.enable = true;
    ombi.enable = true;
    # Second download source: public torrent indexers are thin on music, so
    # Soulseek fills the gap. soularr drives it from Lidarr's wanted list.
    # NOTE: the NAS is on a Mullvad full tunnel and Mullvad dropped port
    # forwarding in 2023, so slskd takes no incoming peer connections. It can
    # still download; uploads and share visibility are degraded. See docs/music.md.
    slskd = {
      enable = true;
      credentialsFile = config.sops.secrets."slskd-credentials".path;
      shareMusic = true;
    };
    soularr.enable = true;
    mullvad.enable = true;
    jellyseerr.enable = true;
    flaresolverr.enable = true;
    nixCache.enable = true;
    # This host serves the cache; reach it on the server subnet, not the fw alias.
    nixCache.clientHost = "192.168.100.76";

    dns.enable = true;
    reverseProxy.enable = true;
    landingPage.enable = true;

    # Read-only HTTP file drop at http://files.lan/public/ (and, for VPN peers
    # who cannot resolve .lan, http://192.168.1.76/public/). Path defaults to
    # /mnt/storage/public. See docs/runbooks/nas-public-share.md.
    publicFiles.enable = true;

    flakeUpdater = {
      enable = true;
      # Headroom, not a fix for any one host. 45min (the option default) was
      # blown by asus-m15 in 2026-W33 compiling electron from source; that
      # specific cause is fixed properly in the asus-m15 host config (its
      # unstable-override of chromium was poisoning stable signal-desktop's
      # electron off-cache). 180 stays because the same shape recurs whenever
      # this runs ahead of Hydra on a fresh nixpkgs-unstable rev, and because
      # a host can now build twice under the retry.
      buildTimeoutMinutes = 180;
    };
    localCA.trustCA = true;

    article2pod = {
      enable           = true;
      podcastTitle     = "Lando's Reading Queue";
      podcastAuthor    = "lando";
      podcastDescription = "Articles converted to audio for listening on the road";
      # TODO: after first `rebuild`, pin kokoroImage to digest:
      #   docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/remsky/kokoro-fastapi:v0.5.0-cpu
      # then set: kokoroImage = "ghcr.io/remsky/kokoro-fastapi@sha256:<digest>";
    };

    mediaLinker = {
      enable = true;
      mediaUsers = [
        # Look up Jellyseerr user IDs at http://192.168.1.76:5055/users
        # and replace the placeholder IDs below.
        { name = "chris"; jellyseerrId = 3; }
        { name = "blaney"; jellyseerrId = 5; }
        { name = "em"; jellyseerrId = 6; }
        { name = "russell"; jellyseerrId = 8; }
        { name = "cmoore"; jellyseerrId = 7; }
      ];
    };

    # Encrypted USB backup of /mnt/private.
    # One-time setup (run on optiplex-nas as root):
    #   dd if=/dev/urandom of=/root/secrets/backup-usb.key bs=4096 count=1
    #   chmod 600 /root/secrets/backup-usb.key
    #   cryptsetup luksAddKey /dev/sdX /root/secrets/backup-usb.key  # enter existing passphrase
    #   blkid /dev/sdX  # copy the UUID value, set it below, enable = true, rebuild
    # After setup: plugging in the USB auto-starts the backup. Monitor with:
    #   journalctl -u private-backup -f
    privateBackup = {
      enable = false;
      luksUuid = "PLACEHOLDER";  # replace after running blkid on the USB drive
    };
  };

  # Consumed by the bazarr-provision unit to enable the opensubtitlescom
  # provider. Sourced from defaultSopsFile (secrets/optiplex-nas.yaml).
  sops.secrets."opensubtitles-credentials" = { };

  # Consumed by slskd as an EnvironmentFile. Holds SLSKD_SLSK_USERNAME /
  # SLSKD_SLSK_PASSWORD (the slsknet.org account) and SLSKD_USERNAME /
  # SLSKD_PASSWORD (the web UI login). Also from defaultSopsFile.
  sops.secrets."slskd-credentials" = { };
}
