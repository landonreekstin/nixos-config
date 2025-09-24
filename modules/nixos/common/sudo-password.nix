# ~/nixos-config/modules/nixos/common/sudo-password.nix
{ config, lib, ... }:

let
  cfg = config.customConfig;
  # Hardcode the path to the secondary password file
  sudoPasswordFile = "/etc/security/sudo_passwd";
in
{
  # Only apply these changes if the feature is enabled for the host.
  config = lib.mkIf cfg.user.sudoPassword {

    security.pam.services.sudo = {
      text = ''
        # Use pam_pwdfile to authenticate against a separate password file.
        auth      required  pam_pwdfile.so pwdfile=${sudoPasswordFile}

        # Use the standard system configuration for everything else.
        account   include   system-auth
        password  include   system-auth
        session   include   system-auth
      '';
    };

    # This ensures the directory and file exist with secure permissions,
    # even if the install script fails to create it. This is robust.
    # The file will be empty and owned by root, ready for the install script.
    system.activationScripts.setupSudoPasswdFile = {
      text = ''
        mkdir -p /etc/security
        touch ${sudoPasswordFile}
        chmod 0600 ${sudoPasswordFile}
        chown root:root ${sudoPasswordFile}
      '';
      deps = [ "users" ];
    };

  };
}