# ~/nixos-config/modules/nixos/common/system-tweaks.nix
{ config, pkgs, lib, ... }:
{
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';

  # Allow the primary user to run nixos-rebuild without a password so that
  # the update-notification "Sync & Rebuild" action can work from a systemd
  # user service (which has no TTY to prompt on).
  security.sudo.extraRules = lib.mkIf
    config.customConfig.homeManager.services.updateNotification.enable
    [{
      users = [ config.customConfig.user.name ];
      commands = [{
        command = "/run/current-system/sw/bin/nixos-rebuild";
        options = [ "NOPASSWD" ];
      }];
    }];
}