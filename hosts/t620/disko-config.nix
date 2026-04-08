# ~/nixos-config/hosts/t620/disko-config.nix
#
# Single-disk btrfs layout for the HP T620 (64GB SSD).
#
# IMPORTANT: Set `main_disk` to the actual device path before running the
# install script. On most thin clients this will be /dev/sda (SATA SSD)
# or /dev/nvme0n1 (NVMe). Check with `lsblk` on the live installer.

let
  main_disk = "/dev/sda"; # <-- set this to match the actual disk at install time
in
{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = main_disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                subvolumes = {
                  "/@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "4G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
