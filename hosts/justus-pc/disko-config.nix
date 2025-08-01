# ~/nixos-config/hosts/justus-pc/disko-config.nix
{ lib, config, ... }:
{

    disko.devices = {
        disk = {
            main = {
                type = "disk";
                device = "/dev/nvme0n1";
                content = {
                    type = "gpt";
                    partitions = {
                        boot = {
                            size = "1G";
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