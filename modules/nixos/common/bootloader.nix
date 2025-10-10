# ~/nixos-config/modules/nixos/common/bootloader.nix
{ config, pkgs, lib, ... }:
let
  quietBootEnabled = config.customConfig.bootloader.quietBoot;
in
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };
  boot.initrd.verbose = !quietBootEnabled;
  boot.loader.timeout = if quietBootEnabled then 0 else 5;
  boot.consoleLogLevel = if quietBootEnabled then 0 else 4;
  boot.kernelParams = lib.mkIf quietBootEnabled [
    "quiet"
    "splash" # Often used with "quiet" for Plymouth splash screens
    "udev.log_level=3"
    "rd.udev.log_level=3"
  ];
}