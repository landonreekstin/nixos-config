# ~/nixos-config/hosts/asus-laptop/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
      shell.bash.color = "blue";
      sopsPassword = true;
    };

    bootloader = {
      quietBoot = true;
      plymouth = {
        enable = true;
        theme = "green_blocks";
      };
    };

    system = {
      hostName = "asus-laptop";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

  };
}
