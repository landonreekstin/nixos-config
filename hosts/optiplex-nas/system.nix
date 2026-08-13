# ~/nixos-config/hosts/optiplex-nas/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      # This will be created during your installation.
      name = "lando"; # Or whatever user your script creates
      email = "landonreekstin@gmail.com";
      shell.bash.color = "bright-magenta";
    };

    system = {
      hostName = "optiplex-nas";
      stateVersion = "25.05"; # Match your flake's version
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

  };
}
