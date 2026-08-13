# ~/nixos-config/hosts/justus-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "justus";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "justus-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = true;
    };

  };
}
