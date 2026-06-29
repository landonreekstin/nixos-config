# ~/nixos-config/modules/nixos/homelab/game-backup.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.gameBackup;
in
{
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
