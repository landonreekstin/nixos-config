# ~/nixos-config/modules/nixos/homelab/nas-client.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.nasClient;
in
{
  config = lib.mkIf cfg.enable {
    # cifs-utils provides the mount.cifs helper required for CIFS fileSystems
    environment.systemPackages = [ pkgs.cifs-utils ];

    fileSystems.${cfg.mountPoint} = {
      device = "//192.168.1.76/storage";
      fsType = "cifs";
      options = [
        "credentials=${cfg.credentialsFile}"
        "uid=1000"
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
