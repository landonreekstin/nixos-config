# ~/nixos-config/hosts/gaming-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "lando";
      # home = "/home/lando"; # Defaults correctly based on user.name
      email = "landonreekstin@gmail.com";
      shell.bash.color = "blue";
      sopsPassword = true;
    };

    system = {
      hostName = "gaming-pc"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
      betaTesterHost = true;
    };

    bootloader = {
      quietBoot = false;
      # Boot partition is ~1GB and NVIDIA early-KMS initrds are large (~130MB/gen),
      # but clearing the leftover Arch kernels freed 211MB, so 10 fits comfortably.
      configurationLimit = 10;
      plymouth = {
        enable = true;
        theme = "circuit";
      };
    };

  };
}
