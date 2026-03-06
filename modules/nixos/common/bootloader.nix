# ~/nixos-config/modules/nixos/common/bootloader.nix
{ config, pkgs, lib, ... }:
let
  quietBootEnabled = config.customConfig.bootloader.quietBoot;
  plymouthEnabled = config.customConfig.bootloader.plymouth.enable;
  quietOrPlymouth = quietBootEnabled || plymouthEnabled;
in
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };

  boot.plymouth = lib.mkIf plymouthEnabled {
    enable = true;
    theme = config.customConfig.bootloader.plymouth.theme;
    themePackages = [ pkgs.adi1090x-plymouth-themes ];
  };

  boot.initrd.verbose = !quietOrPlymouth;
  boot.loader.timeout = if quietBootEnabled then 0 else 5;
  boot.consoleLogLevel = if quietOrPlymouth then 0 else 4;
  boot.kernelParams = lib.mkIf quietOrPlymouth [
    "quiet"
    "splash"
    "udev.log_level=3"
    "rd.udev.log_level=3"
  ];
}