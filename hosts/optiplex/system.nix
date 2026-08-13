# ~/nixos-config/hosts/optiplex/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "lando"; # Your username for the Optiplex
      # home = "/home/lando"; # Defaults correctly based on user.name
      email = "landonreekstin@gmail.com";
      shell.bash.color = "bright-cyan";
      sopsPassword = true;
    };

    system = {
      hostName = "optiplex"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };

    bootloader = {
      configurationLimit = 10;  # 2GB boot partition (after reinstall) - holds up to 10 generations
      plymouth = {
        enable = true;
        theme = "hexagon_hud";  # HUD-style boot splash matching Century Series
      };
    };

  };

  # Disable sops secrets file validation during reinstall (secrets/optiplex.yaml
  # is absent until post-install pushes the newly-encrypted file after reinstall).
  # Remove this once the reinstall is complete and the secrets file exists again.
  sops.validateSopsFiles = false;
}
