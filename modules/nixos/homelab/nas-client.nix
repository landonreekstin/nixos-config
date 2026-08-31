# ~/nixos-config/modules/nixos/homelab/nas-client.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.nasClient;
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
  };

  config = lib.mkIf cfg.enable {
    # cifs-utils provides the mount.cifs helper required for CIFS fileSystems
    environment.systemPackages = [ pkgs.cifs-utils ];

    sops.secrets.smb-credentials = {
      sopsFile = ../../../secrets/common.yaml;
    };

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
  };
}
