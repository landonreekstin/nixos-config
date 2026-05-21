# ~/nixos-config/hosts/optiplex/disko-config.nix
{ lib, config, ... }:
{
    # Disable disko's auto-generated fileSystems options so they don't conflict
    # with hardware-configuration.nix on the current disk. The install script
    # still uses this file to partition the disk correctly. After reinstall,
    # hardware-configuration.nix will be regenerated to match the new layout.
    disko.enableConfig = false;

    disko.devices = {
        disk = {
            main = {
                type = "disk";
                device = "/dev/sda";
                content = {
                    type = "gpt";
                    partitions = {
                        boot = {
                            size = "2G";
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
                                type = "filesystem";
                                format = "ext4";
                                mountpoint = "/";
                            };
                        };
                    };
                };
            };
        };
    };
}
