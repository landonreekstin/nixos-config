# ~/nixos-config/modules/nixos/common/internationalisation.nix
{ config, pkgs, lib, ... }:
{
  time.timeZone = config.customConfig.system.timeZone;
  i18n.defaultLocale = config.customConfig.system.locale;
  i18n.extraLocaleSettings = lib.mkIf (config.customConfig.system.locale == "en_US.UTF-8") {
    LC_ADDRESS = "en_US.UTF-8"; LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8"; LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8"; LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8"; LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  console.keyMap = "us"; # Universal console keymap
}