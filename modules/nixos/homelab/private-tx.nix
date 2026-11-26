# ~/nixos-config/modules/nixos/homelab/private-tx.nix
{ config, lib, pkgs, ... }:

# TX drop folder: anything put into `source` (a folder on the everyday storage share) is
# moved, entirely on this host, into `target` (a folder on the encrypted private share).
# lando drops media in over his everyday tunnel and only sees it again over the private
# tunnel. Nothing here touches the network: no port, no credential, no new user.
#
# Design rules, each one load-bearing:
#   * Fail closed. Nothing moves unless BOTH drives are real mountpoints, so a missing
#     LUKS drive leaves files where they are instead of writing them, unencrypted, onto
#     the root filesystem (the same trap samba-private guards against in samba.nix).
#   * Only finished uploads move. An entry waits until no process (i.e. smbd mid-transfer)
#     has any file under it open AND nothing under it changed for `settleSeconds`.
#   * Atomic arrival. Copy into a staging dir on the private drive, then rename into
#     `target`, then delete the source. A failed copy never leaves a half item in
#     `target`, and the source is kept.
#   * No clobbering. A name that already exists in `target` lands as "<name> (TX <time>)".
#   * No name leaks. The journal is on the unencrypted root disk, so the mover logs only
#     counts, and every command's stderr (which would quote paths) goes to /dev/null.
#     It never opens file contents beyond the copy itself.
#
# One-time setup, on the MOUNTED filesystems (not tmpfiles: that races the nofail
# mounts and can create look-alike dirs on the root fs; see hosts/optiplex-nas/storage.nix):
#   sudo install -d -m 0700 -o lando -g media /mnt/storage/TX
#   sudo install -d -m 0700 -o root  -g root  /mnt/private/.tx-staging
# TX is 0700 so Jellyfin, gamarr and the *arr stack (group media) cannot see into it; with
# the storage share's `inherit permissions`, everything written there is lando-only too.
#
# See docs/networking.md ("The TX drop folder") for the residual risks.

let
  cfg = config.customConfig.homelab.privateTx;
  user = config.customConfig.user.name;

  mover = pkgs.writeShellApplication {
    name = "private-tx-mover";
    runtimeInputs = with pkgs; [ coreutils findutils psmisc util-linux ];
    text = ''
      SRC=${lib.escapeShellArg cfg.source}
      DST=${lib.escapeShellArg cfg.target}
      STAGE=${lib.escapeShellArg cfg.stagingDir}
      SETTLE=${toString cfg.settleSeconds}

      drives_ok() {
        mountpoint -q ${lib.escapeShellArg cfg.privateMount} \
          && mountpoint -q ${lib.escapeShellArg cfg.storageMount}
      }

      # Metadata fingerprint of an entry (names, sizes, mtimes), used to prove the
      # source did not change while it was being copied. Hashed: never printed.
      fingerprint() {
        find "$1" -printf '%P\0%s\0%T@\0' 2>/dev/null | sha256sum
      }

      # 0 when the entry is quiet: no open files, nothing changed in the last SETTLE s.
      settled() {
        local since
        since=$(( $(date +%s) - SETTLE ))
        if [ -n "$(find "$1" \( -newermt "@$since" -o -newerct "@$since" \) -print -quit 2>/dev/null)" ]; then
          return 1
        fi
        # No `--`: psmisc's fuser rejects it and exits 1, which reads as "nothing open".
        # Paths from find are absolute, so none can be mistaken for an option.
        if find "$1" -print0 2>/dev/null | xargs -0 -r fuser -s >/dev/null 2>&1; then
          return 1
        fi
        return 0
      }

      # Move one entry. 0 = moved, 1 = failed (source kept).
      move_one() {
        local e="$1" name dest work before
        name=$(basename -- "$e")
        dest="$DST/$name"
        if [ -e "$dest" ] || [ -L "$dest" ]; then
          dest="$DST/$name (TX $(date +%Y-%m-%d_%H-%M-%S))"
          if [ -e "$dest" ] || [ -L "$dest" ]; then return 1; fi
        fi

        before=$(fingerprint "$e")
        work=$(mktemp -d -p "$STAGE" 2>/dev/null) || return 1

        # Timestamps only: mode and owner are normalised right after, and
        # setuid/setgid are stripped (the storage pool's dirs are SGID media).
        # The source is re-checked (unchanged AND not open) before anything is deleted.
        if cp -R --no-dereference --preserve=timestamps -- "$e" "$work/item" 2>/dev/null \
          && chown -R ${user}:users -- "$work/item" 2>/dev/null \
          && find "$work/item" -type d -exec chmod 0775 {} + 2>/dev/null \
          && find "$work/item" -type f -exec chmod 0664 {} + 2>/dev/null \
          && [ "$(fingerprint "$e")" = "$before" ] \
          && settled "$e" \
          && mv -T -- "$work/item" "$dest" 2>/dev/null; then
          rmdir -- "$work" 2>/dev/null || true
          rm -rf -- "$e" 2>/dev/null || return 1
          return 0
        fi
        rm -rf -- "$work" 2>/dev/null || true
        return 1
      }

      last_report=""
      while :; do
        if ! drives_ok; then
          echo "a drive is not mounted; leaving TX untouched"
          exit 0
        fi

        moved=0 failed=0 pending=0
        while IFS= read -r -d $'\0' e; do
          if ! settled "$e"; then
            pending=$((pending + 1))
          elif ! drives_ok; then
            failed=$((failed + 1))
          elif move_one "$e"; then
            moved=$((moved + 1))
          else
            failed=$((failed + 1))
          fi
        done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

        [ "$moved" -gt 0 ] && echo "moved $moved item(s) into the private upload folder"
        report="failed=$failed pending=$pending"
        if [ "$report" != "$last_report" ] && { [ "$failed" -gt 0 ] || [ "$pending" -gt 0 ]; }; then
          echo "$failed item(s) failed, $pending item(s) still uploading"
        fi
        last_report=$report

        if [ -z "$(find "$SRC" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
          exit 0
        fi
        if [ "$failed" -gt 0 ]; then sleep 60; else sleep 3; fi
      done
    '';
  };
in
{
  options.customConfig.homelab.privateTx = with lib; {
    enable = mkEnableOption "the TX drop folder that moves files from the storage share into the private share";
    source = mkOption {
      type = types.str;
      default = "/mnt/storage/TX";
      description = "Drop folder on the storage share. Must already exist (see the module header).";
    };
    target = mkOption {
      type = types.str;
      default = "/mnt/private/upload";
      description = "Destination folder on the private share.";
    };
    stagingDir = mkOption {
      type = types.str;
      default = "/mnt/private/.tx-staging";
      description = "Root-only staging dir on the same filesystem as `target`, so arrival is an atomic rename.";
    };
    storageMount = mkOption {
      type = types.str;
      default = "/mnt/storage";
      description = "Mountpoint that holds `source`.";
    };
    privateMount = mkOption {
      type = types.str;
      default = config.customConfig.homelab.samba.private.path;
      defaultText = literalExpression "config.customConfig.homelab.samba.private.path";
      description = "Mountpoint that holds `target`; nothing moves unless it is mounted.";
    };
    settleSeconds = mkOption {
      type = types.ints.positive;
      default = 10;
      description = "An entry must be unchanged (and not open) for this long before it is moved.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.private-tx = {
      description = "Move the TX drop folder into the private share";
      unitConfig = {
        RequiresMountsFor = [ cfg.storageMount cfg.privateMount ];
        ConditionPathIsMountPoint = [ cfg.storageMount cfg.privateMount ];
        ConditionPathIsDirectory = [ cfg.source cfg.target cfg.stagingDir ];
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe mover;
        # Root only so fuser can see smbd's open files; everything else is fenced off.
        CapabilityBoundingSet = [
          "CAP_SYS_PTRACE" "CAP_DAC_READ_SEARCH" "CAP_DAC_OVERRIDE" "CAP_CHOWN" "CAP_FOWNER"
        ];
        PrivateNetwork = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        IPAddressDeny = "any";
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.source cfg.target cfg.stagingDir ];
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };

    # Fires as soon as anything lands in TX.
    systemd.paths.private-tx = {
      wantedBy = [ "multi-user.target" ];
      unitConfig.RequiresMountsFor = [ cfg.storageMount cfg.privateMount ];
      pathConfig.DirectoryNotEmpty = cfg.source;
    };

    # Safety net in case a trigger is missed (e.g. TX filled while the private drive was down).
    systemd.timers.private-tx = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "15min";
      };
    };
  };
}
