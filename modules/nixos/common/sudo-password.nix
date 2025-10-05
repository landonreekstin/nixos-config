# ~/nixos-config/modules/nixos/common/sudo-password.nix
{ config, lib, ... }:

let
  cfg = config.customConfig;
in
{
  # Only apply these changes if the feature is enabled for the host.
  config = lib.mkIf cfg.user.sudoPassword {

    # The install script uses `chpasswd` to set the initial user password.
    # We override its PAM configuration to be a minimal service that ONLY
    # uses pam_unix to set the password. This bypasses the default password
    # quality checks (pam_pwquality) and allows a weak password to be set
    # for the graphical login, which is our specific goal for this host.
    security.pam.services.chpasswd.text = ''
      password required ${config.security.pam.package}/lib/security/pam_unix.so
    '';

    # Add the 'rootpw' option to the sudoers configuration.
    # This tells sudo to prompt for the root user's password instead of
    # the invoking user's password.
    security.sudo.extraConfig = ''
      Defaults rootpw
    '';

  };
}