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
    };
    transmission.enable = true;
    mullvad.enable = true;
    jellyseerr.enable = true;
    flaresolverr.enable = true;
    nixCache.enable = true;
    # This host serves the cache; reach it on the server subnet, not the fw alias.
    nixCache.clientHost = "192.168.100.76";

    dns.enable = true;
    reverseProxy.enable = true;
    landingPage.enable = true;

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
}
