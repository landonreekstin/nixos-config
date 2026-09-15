# ~/nixos-config/hosts/optiplex-nas/storage.nix
{ config, pkgs, lib, ... }:

# Storage pool, swap and the LUKS-encrypted private share for this host.
# Disk *partitioning* is declared separately in ./disko-config.nix.
{
  # 1. Tell the boot process to include Btrfs support
  boot.initrd.supportedFilesystems = [ "btrfs" ];

  # Define the mount options for the external HDD storage pool.
  fileSystems."/mnt/storage" = {
    # This device path comes from the partlabel we set in Disko.
    device = "/dev/disk/by-partlabel/disk-hdd1-storage";
    fsType = "btrfs";
    # mkBefore keeps these ahead of the "defaults" that disko contributes for the
    # same mount, preserving the exact /etc/fstab line this host had when the block
    # lived in default.nix. (Top-level flake modules like disko are merged before
    # a host's sub-modules, so without it the order would flip. Inert either way —
    # "defaults" conflicts with none of these — but it keeps fstab churn-free.)
    options = lib.mkBefore [
      # Standard options for BTRFS
      "noatime"
      "compress=zstd"
      # This is the crucial option:
      # It tells systemd not to halt the boot process if this device isn't ready.
      "nofail"
    ];
  };

  # 2. Create and enable a swap file on our dedicated swap subvolume
  swapDevices = [
    {
      device = "/.swapvol/swapfile";
      size = 8 * 1024; # 8GB swap file, adjust as needed
    }
  ];

  # === Encrypted Drive for Private Samba Share ===
  boot.initrd.systemd.enable = true; # Ensure systemd is used in initrd for handling encrypted volumes
  # copies the keyfile into the initrd so it's available at boot time
  boot.initrd.secrets."/secrets/private_luks.key" = "/root/secrets/private_luks.key";
  fileSystems."/mnt/private" = {
    fsType = "ext4";
    # This specifies the decrypted device that will be mounted.
    device = "/dev/mapper/private";
    # These options are crucial for removable drives.
    # 'nofail' prevents an error if the device isn't present at boot.
    # 'x-systemd.device-timeout=1' tells systemd to only wait 1 second
    # for the device to appear, preventing long boot delays.
    options = [ "nofail" "x-systemd.device-timeout=10s" ];

    # This section tells NixOS how to create the "/dev/mapper/private" device.
    encrypted = {
      enable = true;
      label = "private";
      # Point to the actual, physical encrypted partition.
      blkDev = "/dev/disk/by-uuid/2ec75d33-7943-47d2-a9c3-dd11d996f9f0";
      keyFile = "/secrets/private_luks.key";
    };
  };

  # === Samba mount point permissions ===
  # Deliberately NOT done with systemd.tmpfiles `d` rules. Two problems with that,
  # both observed on this host:
  #
  #   1. The rules race the mounts. tmpfiles wins on a mount that is slow or absent
  #      (both of these are `nofail`), so it creates a look-alike directory on the
  #      ROOT filesystem which the real mount then hides — or, worse, doesn't. When
  #      the LUKS drive failed to enumerate on 2026-09-14, /mnt/private was exactly
  #      that: an empty root-fs directory that Samba was still exporting writable.
  #   2. The rules disagreed with reality anyway. They declared `lando:users 0775`,
  #      while both filesystems are actually `lando:media 2775` — SGID with the media
  #      group, which is what lets Jellyfin and the *arr stack share files. Had
  #      tmpfiles ever won the race against the mount, it would have stripped the
  #      SGID bit and the group.
  #
  # Ownership is a property of the filesystem and persists across boots, so it only
  # needs setting once, on the mounted filesystem:
  #   sudo chown lando:media /mnt/storage && sudo chmod 2775 /mnt/storage
  #
  # samba-private additionally refuses to start unless its path is a real mountpoint
  # (see modules/nixos/homelab/samba.nix).

  # === Don't wait 90s at boot for a missing private drive ===
  # The LUKS drive is unlocked in the initrd, so the `nofail` and
  # `x-systemd.device-timeout=10s` on the /mnt/private MOUNT above do not apply to
  # the wait for its BACKING DEVICE — that is a separate device unit which gets
  # systemd's 90s DefaultDeviceTimeout. Capping it here keeps a dead or unplugged
  # private drive to a short pause instead of a minute and a half of boot hang.
  # Kept generous enough for the NVMe root and the USB storage pool to appear.
  boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "30s";
}
