# ~/nixos-config/hosts/atl-mini-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "heather";
      email = "landonreekstin@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "atl-mini-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = true;
    };

  };
}
