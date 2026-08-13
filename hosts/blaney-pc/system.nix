# ~/nixos-config/hosts/blaney-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "blaney-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };

    bootloader.plymouth = {
      enable = true;
      theme = "hexa_retro";
    };

  };
}
