# ~/nixos-config/modules/nixos/homelab/nas-client.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.nasClient;

  # Open the mount in the host's configured graphical file manager rather than
  # xdg-open: on gaming-pc the inode/directory MIME default is kitty, so xdg-open
  # would drop you in a terminal instead of Dolphin.
  fileManager = config.customConfig.apps.programs.fileManager.command;

  # Manual, on-demand mount of the NAS's private share.
  #
  # The private share is a SECOND smbd on the NAS listening on its own port (4445 by
  # default, see modules/nixos/homelab/samba.nix), exporting the LUKS-encrypted USB
  # drive mounted at /mnt/private there. It is deliberately not a `fileSystems` entry
  # on this host: no fstab line, no x-systemd.automount, no _netdev unit. Nothing
  # mounts it except someone running this command, and `private-share -u` puts it away.
  #
  # mount.cifs is invoked directly rather than through `mount -t cifs` so the mount
  # helper never has to be found on PATH under sudo.
  privateShareCmd = pkgs.writeShellScriptBin "private-share" ''
    #!${pkgs.stdenv.shell}
    set -uo pipefail

    MOUNTPOINT_BIN=${pkgs.util-linux}/bin/mountpoint
    UMOUNT=${pkgs.util-linux}/bin/umount
    MOUNT_CIFS=${pkgs.cifs-utils}/bin/mount.cifs
    BASH=${pkgs.bash}/bin/bash
    TIMEOUT=${pkgs.coreutils}/bin/timeout

    SERVER=${lib.escapeShellArg cfg.serverAddress}
    SHARE=${lib.escapeShellArg cfg.privateShare.share}
    PORT=${toString cfg.privateShare.port}
    DIR=${lib.escapeShellArg cfg.privateShare.mountPoint}
    CREDS=${lib.escapeShellArg config.sops.secrets.smb-credentials.path}
    OWNER=${lib.escapeShellArg config.customConfig.user.name}
    FILEMANAGER=${lib.escapeShellArg fileManager}

    # The store copy of sudo isn't setuid — only the NixOS security wrapper works.
    SUDO=/run/wrappers/bin/sudo
    [ -x "$SUDO" ] || SUDO=sudo

    usage() {
      cat <<'USAGE'
    Usage: private-share        mount the NAS private share and open it
           private-share -u     unmount it
           private-share -s     is it mounted?
           private-share -h     this help

    Nothing here happens automatically: the share is never mounted at boot or on
    access, only when this command is run. It stays mounted until you unmount it.
    USAGE
    }

    is_mounted() { "$MOUNTPOINT_BIN" -q "$DIR"; }

    # Only open a file manager when there is a graphical session to open it in —
    # this command is just as usable over SSH.
    open_in_file_manager() {
      [ -n "''${DISPLAY-}''${WAYLAND_DISPLAY-}" ] || return 0
      [ -n "$FILEMANAGER" ] || return 0
      # Intentionally unquoted: the registry command may carry arguments.
      # shellcheck disable=SC2086
      $FILEMANAGER "$DIR" >/dev/null 2>&1 &
    }

    do_mount() {
      if is_mounted; then
        echo "Already mounted at $DIR"
        open_in_file_manager
        exit 0
      fi

      if ! "$TIMEOUT" 5 "$BASH" -c "exec 3<>/dev/tcp/$SERVER/$PORT" 2>/dev/null; then
        echo "Can't reach $SERVER:$PORT — nothing mounted." >&2
        echo >&2
        echo "Two things to check, in this order:" >&2
        echo "  1. Is the tunnel up?    ip -brief addr show wg-nas" >&2
        echo "  2. Is the drive served? The NAS only runs samba-private while" >&2
        echo "     /mnt/private is a real mountpoint, so an unplugged or locked" >&2
        echo "     private drive closes this port rather than serving an empty one." >&2
        exit 1
      fi

      "$SUDO" ${pkgs.coreutils}/bin/mkdir -p "$DIR" || exit 1

      # uid= takes the USERNAME, not a number. The share is exported with no unix
      # extensions, so the client decides ownership locally and it must resolve to
      # whoever reads the mount or every write fails with EACCES. `lando` is uid 1000
      # on some hosts and 1002 on gaming-pc (uid is auto-allocated — users.users.<u>.uid
      # is null repo-wide), so a numeric literal here would only ever be right by luck.
      if ! "$SUDO" "$MOUNT_CIFS" "//$SERVER/$SHARE" "$DIR" \
             -o "credentials=$CREDS,port=$PORT,uid=$OWNER,gid=100,iocharset=utf8"; then
        # Leave no empty directory behind on failure: an unmounted /mnt/... that still
        # exists is a place for a stray write to land on the LOCAL disk, which is
        # exactly how the NAS ended up serving a "private" share off its root fs.
        "$SUDO" ${pkgs.coreutils}/bin/rmdir "$DIR" 2>/dev/null || true
        exit 1
      fi

      echo "Mounted //$SERVER/$SHARE at $DIR"
      echo "Unmount when you're done with:  private-share -u"
      open_in_file_manager
    }

    do_unmount() {
      if ! is_mounted; then
        echo "Not mounted."
        "$SUDO" ${pkgs.coreutils}/bin/rmdir "$DIR" 2>/dev/null || true
        exit 0
      fi
      if ! "$SUDO" "$UMOUNT" "$DIR"; then
        echo "Could not unmount $DIR — is something still using it?" >&2
        exit 1
      fi
      "$SUDO" ${pkgs.coreutils}/bin/rmdir "$DIR" 2>/dev/null || true
      echo "Unmounted $DIR"
    }

    case "''${1-}" in
      -h|--help)     usage; exit 0 ;;
      -u|--unmount)  do_unmount; exit 0 ;;
      -s|--status)
        if is_mounted; then echo "Mounted at $DIR"; else echo "Not mounted."; fi
        exit 0
        ;;
      "")            do_mount; exit 0 ;;
      *)             usage >&2; exit 1 ;;
    esac
  '';
in
{
  options.customConfig.homelab.nasClient = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Mount the homelab NAS (optiplex-nas, 192.168.1.76) storage share via
        CIFS. Works on LAN and over WireGuard full-tunnel VPN.
        Credentials are managed via SOPS: add a `smb-credentials` key to
        secrets/common.yaml with the content:
          username=<samba-user>
          password=<samba-password>
      '';
    };
    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/nas";
      description = "Local path where the NAS storage share will be mounted.";
    };
    serverAddress = mkOption {
      type = types.str;
      default = "192.168.1.76";
      description = ''
        IP or hostname of the NAS as reached from this host. Default is the
        legacy main-LAN IP; override for hosts that route to the NAS by a
        different address (e.g. gaming-pc reaches it via a dedicated LAN
        WireGuard tunnel at 192.168.100.76 post-migration).
      '';
    };

    privateShare = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Provide the `private-share` command, a manual on-demand mount of the NAS's
          private share — the LUKS-encrypted drive it serves from a second smbd on
          its own port.

          This deliberately creates no `fileSystems` entry: there is no fstab line,
          no `x-systemd.automount`, and nothing mounts at boot or on first access.
          The share is mounted only by running the command and stays mounted until
          `private-share -u`. Uses the same `smb-credentials` sops secret as the
          storage share above, so it works with `enable = false` too.
        '';
      };
      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/nas-private";
        description = ''
          Local path the `private-share` command mounts into. Created on demand and
          removed again on unmount, so no empty directory is left lying around for a
          stray write to land on the local disk.
        '';
      };
      share = mkOption {
        type = types.str;
        default = "private";
        description = "Name of the share exported by the NAS's private smbd.";
      };
      port = mkOption {
        type = types.port;
        default = 4445;
        description = ''
          TCP port the NAS's private smbd listens on. Must match
          `customConfig.homelab.samba.private.port` on the NAS.
        '';
      };
    };
  };

  config = lib.mkMerge [
    # Shared by both mounts: the mount helper and the credentials secret. Declared
    # for either half so the private share can be used on a host that doesn't
    # automount the storage share.
    (lib.mkIf (cfg.enable || cfg.privateShare.enable) {
      # cifs-utils provides the mount.cifs helper required for CIFS fileSystems
      environment.systemPackages = [ pkgs.cifs-utils ];

      sops.secrets.smb-credentials = {
        sopsFile = ../../../secrets/common.yaml;
      };
    })

    (lib.mkIf cfg.enable {
      fileSystems.${cfg.mountPoint} = {
        device = "//${cfg.serverAddress}/storage";
        fsType = "cifs";
        options = [
          "credentials=${config.sops.secrets.smb-credentials.path}"
          # The share is served with `nounix`, so the server sends no ownership
          # info and the client decides it locally. This must resolve to the user
          # that actually reads/writes the mount, or every write fails with
          # EACCES. `lando` is uid 1000 on some hosts and 1002 on gaming-pc
          # (uid is auto-allocated -- users.users.<u>.uid is null repo-wide), so a
          # numeric literal here is only ever right by luck; mount.cifs resolves a
          # username, which is correct on every host.
          "uid=${config.customConfig.user.name}"
          "gid=100"
          "iocharset=utf8"
          "x-systemd.automount"        # mount on first access, not at boot
          "x-systemd.idle-timeout=60"  # unmount after 60s of inactivity
          "noauto"                     # don't block boot if NAS is unreachable
          "_netdev"                    # wait for network before mounting
        ];
      };
    })

    (lib.mkIf cfg.privateShare.enable {
      environment.systemPackages = [ privateShareCmd ];
    })
  ];
}
