# ~/nixos-config/modules/nixos/common/sudo-password.nix
{ config, lib, unstablePkgs, ... }:

let
  cfg = config.customConfig;
  # Hardcode the path to the secondary password file
  sudoPasswordFile = "/etc/security/sudo_passwd";
in
{
  # Only apply these changes if the feature is enabled for the host.
  config = lib.mkIf cfg.user.sudoPassword {

    # This is the standard NixOS option to make `sudo` ask for the root password
    # instead of the user's password.
    security.sudo.rootPassword = true;

    # As before, we disable password quality checks for the user's weak
    # login password. This is still needed.
    security.pam.enablePasswordQualityChecks = false;

  };
}