# ~/nixos-config/hosts/asus-m15/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "em";
      email = "landonreekstin@gmail.com";
      sudoPassword = true;
    };

    system = {
      hostName = "asus-m15";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Los_Angeles";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = true;
    };

  };
}
