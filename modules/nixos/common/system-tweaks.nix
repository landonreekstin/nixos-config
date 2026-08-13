# ~/nixos-config/modules/nixos/common/system-tweaks.nix
{ config, pkgs, lib, ... }:
{
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';

  # Cap the journal. Without a limit it grows to 10% of the filesystem, which had
  # reached 3.9G on gaming-pc; the NAS and mini-server have no more use for years
  # of logs than the desktops do.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemMaxFileSize=50M
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