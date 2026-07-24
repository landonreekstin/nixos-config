# ~/nixos-config/modules/nixos/homelab/astroneer-snapshots.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.astroneerSnapshots;
  gameCfg = config.customConfig.homelab.gameServers;

  saveParent = "${gameCfg.dataDir}/astroneer/Astro/Saved";
  saveDir = "${saveParent}/SaveGames";

  backend = config.virtualisation.oci-containers.backend;
  containerService = "${backend}-astroneer-server.service";

  snapshotScript = pkgs.writeShellScriptBin "astroneer-snapshot" ''
    set -eu

    SRC="${saveDir}"
    DEST_ROOT="${cfg.snapshotDir}"
    RETENTION=${toString cfg.retention}

    if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC" 2>/dev/null)" ]; then
      echo "no saves present at $SRC — skipping snapshot"
      exit 0
    fi

    mkdir -p "$DEST_ROOT"
    TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
    DEST="$DEST_ROOT/$TS"

    ${pkgs.coreutils}/bin/cp -a "$SRC" "$DEST"
    ${pkgs.coreutils}/bin/touch "$DEST"
    echo "snapshot -> $DEST"

    cd "$DEST_ROOT"
    COUNT=$(ls -1 | wc -l)
    if [ "$COUNT" -gt "$RETENTION" ]; then
      PRUNE=$((COUNT - RETENTION))
      ls -1 | sort | head -n "$PRUNE" | while read -r old; do
        rm -rf -- "$DEST_ROOT/$old"
        echo "pruned $old"
      done
    fi
  '';

  restoreScript = pkgs.writeShellScriptBin "astroneer-restore" ''
    set -eu

    SNAPSHOT_DIR="${cfg.snapshotDir}"
    SAVE_PARENT="${saveParent}"
    SAVE_DIR="${saveDir}"
    SERVICE="${containerService}"

    usage() {
      cat <<EOF
    Usage:
      astroneer-restore --list          List available snapshots (newest first)
      astroneer-restore <timestamp>     Restore SaveGames from the named snapshot
    EOF
    }

    case "''${1-}" in
      ""|-h|--help)
        usage
        exit 0
        ;;
      --list|-l)
        if [ ! -d "$SNAPSHOT_DIR" ] || [ -z "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
          echo "no snapshots yet in $SNAPSHOT_DIR"
          exit 0
        fi
        printf "%-25s  %s\n" "SNAPSHOT" "AGE"
        for snap in $(ls -1 "$SNAPSHOT_DIR" | sort -r); do
          MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$SNAPSHOT_DIR/$snap")
          NOW=$(date +%s)
          AGE=$((NOW - MTIME))
          if [ "$AGE" -lt 3600 ]; then
            HUMAN="$((AGE / 60)) min ago"
          elif [ "$AGE" -lt 86400 ]; then
            HUMAN="$((AGE / 3600)) hr ago"
          else
            HUMAN="$((AGE / 86400)) day(s) ago"
          fi
          printf "%-25s  %s\n" "$snap" "$HUMAN"
        done
        exit 0
        ;;
    esac

    SNAP_NAME="$1"
    SNAP_PATH="$SNAPSHOT_DIR/$SNAP_NAME"
    if [ ! -d "$SNAP_PATH" ]; then
      echo "error: snapshot not found: $SNAP_PATH" >&2
      echo "run 'astroneer-restore --list' to see options" >&2
      exit 1
    fi

    echo "This will:"
    echo "  1. stop $SERVICE"
    echo "  2. move current SaveGames to a .pre-restore-* sibling"
    echo "  3. copy $SNAP_NAME into SaveGames"
    echo "  4. restart $SERVICE"
    printf "Proceed? [y/N] "
    read -r ANSWER
    case "$ANSWER" in
      y|Y|yes|YES) ;;
      *) echo "aborted"; exit 1 ;;
    esac

    TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
    BACKUP="$SAVE_PARENT/SaveGames.pre-restore-$TS"

    ${pkgs.systemd}/bin/systemctl stop "$SERVICE"

    if [ -d "$SAVE_DIR" ]; then
      mv "$SAVE_DIR" "$BACKUP"
      echo "saved current state -> $BACKUP"
    fi

    ${pkgs.coreutils}/bin/cp -a "$SNAP_PATH" "$SAVE_DIR"
    echo "restored $SNAP_NAME -> $SAVE_DIR"

    ${pkgs.systemd}/bin/systemctl start "$SERVICE"
    echo "restarted $SERVICE"
    echo ""
    echo "Pre-restore backup preserved at: $BACKUP"
    echo "Delete it once you've confirmed the restore worked:"
    echo "  rm -rf '$BACKUP'"
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.snapshotDir} 0700 root root - -"
    ];

    environment.systemPackages = [ snapshotScript restoreScript ];

    systemd.services.astroneer-snapshot = {
      description = "Hourly snapshot of Astroneer SaveGames";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${snapshotScript}/bin/astroneer-snapshot";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "astroneer-snapshot";
      };
    };

    systemd.timers.astroneer-snapshot = {
      description = "Hourly snapshot of Astroneer SaveGames";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
