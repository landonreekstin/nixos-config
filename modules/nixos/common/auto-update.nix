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
    # Skip only if a user session is present AND actively in use. A session that is
    # idle (screen locked / no recent input, per logind's IdleHint) still allows the
    # update to proceed. Uses process substitution so `exit` leaves the whole script.
    while read -r _sid _rest; do
      [ -z "$_sid" ] && continue
      if [ "$(loginctl show-session "$_sid" --property=IdleHint --value 2>/dev/null)" = "no" ]; then
        log "Active (non-idle) user session detected — skipping update."
        exit 0
      fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
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
    # The service runs as root but the flake repo is owned by $GIT_USER. Nix's git
    # fetcher rejects a repo not owned by the current user (and ignores git's
    # safe.directory). Setting SUDO_UID to the repo owner makes the ownership check
    # pass — exactly how interactive `sudo nixos-rebuild` works.
    export SUDO_UID="$(id -u "$GIT_USER")"
    ${lib.optionalString cfg.lowPriority "nice -n 19 ionice -c 3"} nixos-rebuild switch \
      --flake "$NIXOS_CONFIG_DIR#$HOSTNAME" --impure --max-jobs auto --cores 0
    log "Rebuild complete."
    ${lib.optionalString cfg.shutdownAfterRebuild ''
    log "shutdownAfterRebuild is set — powering off."
    systemctl poweroff
    ''}
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.nixos-auto-update = {
      description = "Weekly automated NixOS config sync and rebuild";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ config.system.build.nixos-rebuild ]
        ++ (with pkgs; [ git openssh nix coreutils util-linux systemd ]);
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
