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

    services.restic.backups.game-servers = {
      paths = [
        "/var/lib/game-servers"
        "/var/lib/vaultwarden"
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
  };
}
