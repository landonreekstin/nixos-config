# ~/nixos-config/hosts/optiplex-nas/disko-config.nix

# Use a `let` block to define all your device paths in one place.
# This makes the configuration much easier and safer to edit.
# Find the correct device paths by running `ls -la /dev/disk/by-id` from the installer.
let
# --- CONFIGURE YOUR DISKS HERE ---
internal_ssd = "/dev/disk/by-id/ata-your-internal-ssd-id";  # <-- CHANGE THIS
storage_hdd1 = "/dev/disk/by-id/usb-your-first-hdd-id";     # <-- CHANGE THIS
storage_hdd2 = "/dev/disk/by-id/usb-your-second-hdd-id";    # <-- CHANGE THIS
encrypted_usb = "/dev/disk/by-id/usb-your-128gb-drive-id";  # <-- CHANGE THIS

in
{
    disko.devices = {
        disk = {
            # === Internal SSD for OS and Cache ===
            # This disk will be partitioned for the bootloader, NixOS root, and a cache.
            ssd = {
                type = "disk";
                device = internal_ssd; # Use the variable from the let block
                content = {
                    type = "gpt";
                    partitions = {
                        boot = {
                            size = "1G";
                            type = "EF00";
                            content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
                        };
                        root = {
                            size = "64G";
                            content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
                        };
                        cache = {
                            size = "100%FREE";
                            content = { type = "filesystem"; format = "ext4"; mountpoint = "/mnt/cache"; };
                        };
                    };
                };
            };

            # === External HDDs for Mirrored Storage ===
            # These disks are defined here but their content will be created by the
            # logical btrfs volume below. Disko will use the entire disks.
            hdd1 = { type = "disk"; device = storage_hdd1; };
            hdd2 = { type = "disk"; device = storage_hdd2; };

            # === External USB-C for Encrypted Storage ===
            # This disk will be fully encrypted by the logical LUKS volume below.
            usbc = { type = "disk"; device = encrypted_usb; };
        };

        # === Logical Volume Setup (Btrfs RAID1 and LUKS) ===
        btrfs = {
            # Creates a Btrfs filesystem in a RAID1 mirror across two disks.
            storage = {
                type = "btrfs";
                # Use the two HDD devices directly
                devices = [ storage_hdd1 storage_hdd2 ];
                # Set Btrfs RAID level for both data (-d) and metadata (-m)
                extraArgs = [ "-d raid1" "-m raid1" ];
                mountpoint = "/mnt/storage";
            };
        };
        luks = {
            # Creates an encrypted LUKS volume on the specified USB drive.
            content = {
                type = "luks";
                name = "samsung-usb"; # This will be the name in /dev/mapper
                device = encrypted_usb; # Use the USB device directly
                # You will need to configure how the LUKS volume is unlocked.
                # For example, using a key file:
                # keyFile = "/path/to/secret.key";
                # Or it will prompt for a password on boot by default.
                content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/mnt/usb-encrypted";
                };
            };
        };
    };
}