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
  };
}
