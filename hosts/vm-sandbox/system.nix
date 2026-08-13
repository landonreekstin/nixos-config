# ~/nixos-config/hosts/vm-sandbox/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "vm-sandbox";
      stateVersion = "25.11";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    bootloader.quietBoot = false;

  };

  # Throwaway login password (autologin covers the GUI; this is for sudo / TTY).
  users.users.${config.customConfig.user.name}.initialPassword = "vm";
}
