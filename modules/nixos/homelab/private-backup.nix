# ~/nixos-config/modules/nixos/homelab/private-backup.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.privateBackup;

  backupScript = pkgs.writeShellScriptBin "private-backup" ''
    set -euo pipefail

    cleanup() {
      ${pkgs.util-linux}/bin/umount "${cfg.mountPoint}" 2>/dev/null && echo "==> Unmounted ${cfg.mountPoint}" || true
      ${pkgs.cryptsetup}/bin/cryptsetup luksClose "${cfg.mapperName}" 2>/dev/null && echo "==> Closed LUKS volume" || true
    }
    trap cleanup EXIT

    DEVICE=$(${pkgs.util-linux}/bin/blkid -U "${cfg.luksUuid}" 2>/dev/null || true)
    if [ -z "$DEVICE" ]; then
      echo "Error: backup USB drive not found (LUKS UUID: ${cfg.luksUuid})" >&2
      exit 1
    fi
    echo "==> Found backup USB at $DEVICE"

    if [ ! -f "${cfg.keyFile}" ]; then
      echo "Error: keyfile not found at ${cfg.keyFile}" >&2
      echo "  Run: dd if=/dev/urandom of=${cfg.keyFile} bs=4096 count=1 && chmod 600 ${cfg.keyFile}" >&2
      echo "  Then: cryptsetup luksAddKey $DEVICE ${cfg.keyFile}" >&2
      exit 1
    fi

    echo "==> Opening LUKS volume..."
    ${pkgs.cryptsetup}/bin/cryptsetup luksOpen "$DEVICE" "${cfg.mapperName}" \
      --key-file "${cfg.keyFile}"

    mkdir -p "${cfg.mountPoint}"
    ${pkgs.util-linux}/bin/mount /dev/mapper/"${cfg.mapperName}" "${cfg.mountPoint}"
    echo "==> Mounted at ${cfg.mountPoint}"

    echo "==> Syncing ${cfg.sourcePath}/ -> ${cfg.mountPoint}/..."
    ${pkgs.rsync}/bin/rsync -aAHX --delete --info=progress2 \
      "${cfg.sourcePath}/" "${cfg.mountPoint}/"

    echo "==> Backup complete. Cleaning up..."
    # cleanup runs via trap
  '';
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ backupScript ];

    systemd.services.private-backup = {
      description = "Backup ${cfg.sourcePath} to encrypted USB drive";
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/private-backup";
        PrivateDevices = false;
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "private-backup";
      };
    };

    # Auto-start the backup service when the specific USB drive is plugged in.
    # Matches on the LUKS container UUID (not the filesystem UUID inside it).
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_FS_UUID}=="${cfg.luksUuid}", \
        RUN+="${pkgs.systemd}/bin/systemctl --no-block start private-backup.service"
    '';
  };
}
