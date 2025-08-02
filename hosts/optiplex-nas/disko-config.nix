let
  internal_ssd = "/dev/disk/by-id/nvme-WDC_PC_SN520_SDAPNUW-256G-1006_192087801573";
  storage_hdd1 = "/dev/disk/by-id/usb-Seagate_Portable_NB17F5BJ-0:0";
  storage_hdd2 = "/dev/disk/by-id/usb-Seagate_Portable_NAAHBEKQ-0:0";
in
{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = internal_ssd;
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
              # This line is corrected. "100%" means "use all remaining space".
              size = "100%";
              content = {
                type = "btrfs";
                subvolumes = {
                  "/@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@cache" = {
                    mountpoint = "/mnt/cache";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/@swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "8G";
                    };
                  };
                };
              };
            };
          };
        };
      };

      hdd1 = {
        type = "disk";
        device = storage_hdd1;
        content = {
          type = "gpt";
          partitions = {
            storage = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-d" "single"
                  "-m" "raid1"
                  storage_hdd2
                ];
                mountpoint = "/mnt/storage";
              };
            };
          };
        };
      };

      hdd2 = {
        type = "disk";
        device = storage_hdd2;
        content = {
          type = "gpt";
          partitions = {};
        };
      };
    };
  };
}