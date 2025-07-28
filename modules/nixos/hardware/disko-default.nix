# ~/nixos-config/modules/nixos/hardware/disko-default.nix
{ lib, config, ... }:

let
  cfg = config.customConfig.disko-default;
in
{
  # Only activate this module if the user enables it for the host
  config = lib.mkIf cfg.enable {
    # Assert that a device has been specified if the preset is enabled
    assertions = [{
      assertion = cfg.device != "";
      message = "customConfig.disko.enable is true, but customConfig.disko.device is not set.";
    }];

    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = cfg.device; # <-- Use the device from our custom option
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
  };
}