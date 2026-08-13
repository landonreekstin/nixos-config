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

  # === Declaratively set permissions for Samba mount points ===
  # This ensures the 'lando' user, which Samba is forced to use,
  # has the necessary permissions to read and write to the shares.
  systemd.tmpfiles.rules = [
    "d /mnt/storage 0775 lando users - -"
    "d /mnt/private 0775 lando users - -"
  ];
}
