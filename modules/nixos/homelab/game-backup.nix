# ~/nixos-config/modules/nixos/homelab/game-backup.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.gameBackup;
in
{
  options.customConfig.homelab.gameBackup = with lib; {
    enable = mkEnableOption "game server and vaultwarden backups to NAS via restic (daily at 4am)";
    repository = mkOption {
      type = types.str;
      default = "/mnt/nas/backups/mini-server";
      description = "Restic repository path or URI. Defaults to the NAS CIFS mount.";
    };
    passwordFile = mkOption {
      type = types.path;
      default = "/run/secrets/restic-password";
      description = "Path to file containing the restic repository password.";
    };

    # Second copy, OFFSITE: mom's atl-mini-pc, over the homelab VPN, into a rest-server in
    # append-only mode (Homelab 2.0 doc, Stage 0: "small restic backup of irreplaceable
    # files to atl-mini-pc"). Same paths as the NAS job above.
    offsite = {
      enable = mkEnableOption "the offsite copy of this backup to atl-mini-pc";
      repository = mkOption {
        type = types.str;
        default = "rest:http://10.10.0.19:8000/mini-server";
        description = "Restic repository on atl-mini-pc's rest-server (append-only).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."restic-password" = {
      sopsFile = ../../../secrets/mini-server.yaml;
    };

    services.restic.backups.mini-server = {
      paths = [
        "/var/lib/game-servers"
        "/var/lib/vaultwarden"
        "/var/lib/hass"
      ];
      exclude = [
        "/var/lib/hass/deps"
        "/var/lib/hass/tts"
        "*.log"
        "*.log.*"
      ];
      repository = cfg.repository;
      passwordFile = config.sops.secrets."restic-password".path;
      timerConfig = {
        OnCalendar = "04:00";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 3"
      ];
    };

    # Ensure network is up before restic runs (CIFS automount triggers on first access)
    systemd.services."restic-backups-mini-server" = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    # Its own repo password, in its own sops file (secrets/mini-server-offsite.yaml): a file
    # that can be created from any host with just the public keys. Also in the offline kit
    # beside the admin age key, because recovering from the age key's loss is what this
    # copy is for, and a password only sops can open would be locked inside the same loss.
    sops.secrets."restic-offsite-password" = lib.mkIf cfg.offsite.enable {
      sopsFile = ../../../secrets/mini-server-offsite.yaml;
    };

    services.restic.backups.offsite = lib.mkIf cfg.offsite.enable {
      # Mirror the NAS job, including what other modules add to it (forgejo.nix's dump).
      inherit (config.services.restic.backups.mini-server) paths exclude;
      repository = cfg.offsite.repository;
      passwordFile = config.sops.secrets."restic-offsite-password".path;
      initialize = true;
      # After the 04:00 NAS run, so the two never contend for the same files.
      timerConfig = {
        OnCalendar = "04:45";
        Persistent = true;
        RandomizedDelaySec = "15min";
      };
      # No pruneOpts: the server is append-only and refuses deletes, so `forget --prune` here
      # would fail the unit. Retention is run on atl-mini-pc itself, see docs/hosts/atl-mini-pc.md.
    };

    systemd.services."restic-backups-offsite" = lib.mkIf cfg.offsite.enable {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
