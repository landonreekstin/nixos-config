# ~/nixos-config/modules/nixos/common/sudo-password.nix
{ config, lib, ... }:

let
  cfg = config.customConfig;
in
{
  config = lib.mkIf cfg.user.sudoPassword (lib.mkMerge [
    {
      # Configure sudo to prompt for root's password instead of the user's.
      security.sudo.extraConfig = ''
        Defaults rootpw
      '';
    }

    # Sops path: root password hash stored as a secret (preferred for sops-enabled hosts).
    (lib.mkIf cfg.user.sopsPassword {
      sops.secrets.root-password-hash = {
        neededForUsers = true;
      };
      users.users.root.hashedPasswordFile =
        config.sops.secrets.root-password-hash.path;
    })

    # Legacy path: override PAM chpasswd to bypass quality checks so the install
    # script can set a weak graphical-login password without error. Only active
    # on hosts not yet migrated to sops (sopsPassword = false).
    (lib.mkIf (!cfg.user.sopsPassword) {
      security.pam.services.chpasswd.text = ''
        password required ${config.security.pam.package}/lib/security/pam_unix.so
      '';
    })
  ]);
}
