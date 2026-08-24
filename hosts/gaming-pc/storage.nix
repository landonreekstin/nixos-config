# ~/nixos-config/hosts/gaming-pc/storage.nix
{ config, pkgs, lib, ... }:

# Second NVMe (nvme2n1), repurposed from a retired Gentoo install:
#   p1  1G    unused (was Gentoo's ESP)
#   p2  8G    swap  -> nixos-swap
#   p3  1T    ext4  -> /mnt/games (second Steam library)
#   p4  830G  ntfs  -> owned by Windows; deliberately NOT mounted here
#
# Partitioning is manual on this host (no disko), so the partitions are matched
# by label rather than UUID to keep the mapping readable.
{
  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-label/nixos-games";
    fsType = "ext4";
    # nofail + a short timeout so a disk fault degrades to "no games library"
    # instead of blocking boot, same reasoning as hosts/optiplex-nas/storage.nix.
    options = [ "defaults" "nofail" "x-systemd.device-timeout=5s" ];
  };

  # hardware-configuration.nix declares `swapDevices = [ ]`; list options
  # concatenate rather than conflict, so this merges cleanly with it.
  swapDevices = [
    { device = "/dev/disk/by-label/nixos-swap"; }
  ];

  # Ownership of /mnt/games (lando:users, so Steam can write to the library root)
  # is stored on the ext4 filesystem itself and is deliberately NOT re-asserted by
  # a systemd.tmpfiles rule. A tmpfiles rule would race the mount during a rebuild
  # activation and, worse, would create a user-writable /mnt/games on / whenever the
  # nofail mount is absent -- letting Steam quietly install games onto the root disk.
  # Leaving it unmanaged means a missing mount fails loudly instead.
}
