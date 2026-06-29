# ~/nixos-config/modules/nixos/common/auto-update.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.services.autoUpdate;
  userName = config.customConfig.user.name;
  nixosConfigDir = "${config.customConfig.user.home}/nixos-config";
  hostName = config.customConfig.system.hostName;

  autoUpdateScript = pkgs.writeShellScript "nixos-auto-update" ''
    set -euo pipefail

    log() { echo "[auto-update] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

    NIXOS_CONFIG_DIR="${nixosConfigDir}"
    HOSTNAME="${hostName}"
    GIT_USER="${userName}"
    GIT_SSH_COMMAND="ssh -i /home/$GIT_USER/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

    if [ ! -d "$NIXOS_CONFIG_DIR" ]; then
      log "ERROR: Config dir '$NIXOS_CONFIG_DIR' not found. Aborting."
      exit 1
    fi

    ${lib.optionalString cfg.skipIfActiveSession ''
    if [ -n "$(loginctl list-sessions --no-legend 2>/dev/null)" ]; then
      log "Active user session detected — skipping update."
      exit 0
    fi
    ''}

    HEAD_BEFORE=$(runuser -l "$GIT_USER" -c "git -C '$NIXOS_CONFIG_DIR' rev-parse HEAD")
    log "HEAD before pull: $HEAD_BEFORE"

    log "Fetching remote changes..."
    runuser -l "$GIT_USER" -c "GIT_SSH_COMMAND='$GIT_SSH_COMMAND' git -C '$NIXOS_CONFIG_DIR' fetch"

    log "Pulling latest changes..."
    runuser -l "$GIT_USER" -c "GIT_SSH_COMMAND='$GIT_SSH_COMMAND' git -C '$NIXOS_CONFIG_DIR' pull --rebase" || {
      log "ERROR: git pull --rebase failed. Aborting rebuild."
      exit 1
    }

    HEAD_AFTER=$(runuser -l "$GIT_USER" -c "git -C '$NIXOS_CONFIG_DIR' rev-parse HEAD")
    log "HEAD after pull: $HEAD_AFTER"

    if [ "$HEAD_BEFORE" = "$HEAD_AFTER" ]; then
      log "No new commits — skipping rebuild."
      exit 0
    fi

    log "New commits pulled ($HEAD_BEFORE -> $HEAD_AFTER). Running nixos-rebuild switch..."
    ${lib.optionalString cfg.lowPriority "nice -n 19 ionice -c 3"} nixos-rebuild switch \
      --flake "$NIXOS_CONFIG_DIR#$HOSTNAME" --impure --max-jobs auto --cores 0
    log "Rebuild complete."
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.nixos-auto-update = {
      description = "Weekly automated NixOS config sync and rebuild";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [ git openssh nix coreutils util-linux ];
      environment.NIXPKGS_ALLOW_UNFREE = "1";
      unitConfig = lib.optionalAttrs cfg.onlyOnAC {
        ConditionACPower = true;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = autoUpdateScript;
        TimeoutStartSec = 7200;
        SyslogIdentifier = "nixos-auto-update";
      };
    };

    systemd.timers.nixos-auto-update = {
      description = "Timer for weekly automated NixOS sync and rebuild";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "${cfg.day} *-*-* ${cfg.time}:00";
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = cfg.persistent;
      };
    };
  };
}
