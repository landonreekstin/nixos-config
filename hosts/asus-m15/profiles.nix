# ~/nixos-config/hosts/asus-m15/profiles.nix
{ config, pkgs, lib, ... }:

{
  customConfig.profiles = {
    gaming.enable = true;
    development.gbdk.enable = true;
    htpc = {
      enable = true;
      autoLogin.enable = true;
      cec = {
        enable = true;
        powerOnTv = true;
        hdmiPort = 1; # adjust to the HDMI port this machine is plugged into on the TV
      };
      controllerWake.enable = true;
      virtualKeyboard.enable = true;
    };
  };
}
