# ~/nixos-config/hosts/optiplex-nas/disko-config.nix
let
  # --- CONFIGURE YOUR DISKS HERE ---
  # Best practice: use /dev/disk/by-id/ paths to avoid devices changing names.
  # Run `ls -la /dev/disk/by-id` from the installer to find these.
  internal_ssd = "/dev/disk/by-id/nvme-eui.1920878015730001001b448b44c1a736";
  storage_hdd1 = "/dev/disk/by-id/usb-Seagate_Portable_NB17F5BJ-0:0";
  storage_hdd2 = "/dev/disk/by-id/usb-Seagate_Portable_NAAHBEKQ-0:0";
in
{
  disko.devices = {
    disk = {
      # === Internal SSD with Btrfs Subvolumes ===
      ssd = {
        type = "disk";
        device = internal_ssd;
        content = {
          type = "gpt";
          partitions = {
            # Boot partition remains the same
            ESP = {
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            # ONE partition for the entire Btrfs filesystem
            btrfs = {
              size = "100%FREE";
              content = {
                type = "btrfs";
                # We define subvolumes instead of separate filesystems
                subvolumes = {
                  "/@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@cache" = {
                    mountpoint = "/mnt/cache";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  # Swap file needs its own subvolume with No-Copy-on-Write
                  "/@swap" = {
                    mountpoint = "/swap";
                    copyOnWrite = false;
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      };

      # === External HDDs Combined into a Single Volume ===
      hdd1 = {
        type = "disk";
        device = storage_hdd1;
        content = { type = "btrfs"; }; # The whole disk will be a btrfs member
      };
      hdd2 = {
        type = "disk";
        device = storage_hdd2;
        content = { type = "btrfs"; }; # The whole disk will be a btrfs member
      };
    };

    # === Logical Filesystem Setup ===
    fs = {
      # Btrfs volume spanning both HDDs.
      # Data is stored in 'single' mode (like JBOD), giving you 3TB total capacity.
      # Metadata is 'raid1' for better resilience.
      storage = {
        type = "btrfs";
        devices = [ storage_hdd1 storage_hdd2 ];
        extraArgs = [ "-d" "single" "-m" "raid1" ];
        mountpoint = "/mnt/storage";
      };
    };
  };
}