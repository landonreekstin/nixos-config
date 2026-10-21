# ~/nixos-config/modules/nixos/services/remote-admin.nix
{ config, pkgs, lib, ... }:

# A separate admin account that can reach someone else's machine over SSH to do nix work,
# without being their account. Built for blaney-pc: lando gets in over the homelab VPN, but
# never as insideabush, and with sudo limited to an allowlist instead of `wheel`.
#
# The allowlist is a guardrail, not a wall: `nixos-rebuild switch` with a config you wrote
# can do anything as root. What it stops is casual access (`sudo -i`, `sudo cat`). The real
# backstop is visibility — the machine's owner gets a desktop notification whenever the
# admin connects or disconnects, and every sudo command lands in the journal.
#
# Deliberately independent of customConfig.services.ssh: that option also authorises the
# admin keys on the *primary* user (common/users-groups.nix), which is exactly what this
# module exists to avoid.

let
  cfg = config.customConfig.services.remoteAdmin;
  owner = config.customConfig.user.name;

  # pam_exec runs this as root on every sshd session open/close. It must never block or fail
  # a login, so everything is best-effort and capped with a timeout.
  notifyOwner = pkgs.writeShellScript "remote-admin-notify" ''
    [ "$PAM_USER" = "${cfg.user}" ] || exit 0
    case "$PAM_TYPE" in
      open_session)  title="${cfg.displayName} connected";    body="${cfg.displayName} is logged in to this computer remotely to work on its setup (from $PAM_RHOST)." ;;
      close_session) title="${cfg.displayName} disconnected"; body="${cfg.displayName}'s remote session has ended." ;;
      *) exit 0 ;;
    esac
    uid=$(${pkgs.coreutils}/bin/id -u ${owner} 2>/dev/null) || exit 0
    [ -S "/run/user/$uid/bus" ] || exit 0   # owner not logged in to a desktop
    ${pkgs.coreutils}/bin/timeout 5 ${pkgs.util-linux}/bin/runuser -u ${owner} -- \
      ${pkgs.coreutils}/bin/env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
      ${pkgs.libnotify}/bin/notify-send --app-name="Remote access" --icon=network-server \
      "$title" "$body" >/dev/null 2>&1 || true
    exit 0
  '';
in
{
  options.customConfig.services.remoteAdmin = with lib; {
    enable = mkEnableOption "an SSH-only admin account with an allowlisted sudo";
    user = mkOption {
      type = types.str;
      default = "lando";
      description = "Name of the admin account. Must not be the primary user.";
    };
    displayName = mkOption {
      type = types.str;
      default = "Lando";
      description = "How the admin is named in the owner's connect/disconnect notifications.";
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      description = "SSH public keys allowed to log in as the admin account.";
    };
    interface = mkOption {
      type = types.str;
      description = "The only interface sshd is reachable on (e.g. the VPN interface).";
    };
    passwordSopsFile = mkOption {
      type = types.path;
      description = "sops file holding `<user>-password-hash` (a mkpasswd hash), used for sudo.";
    };
    sudoCommands = mkOption {
      type = types.listOf types.str;
      default = map (c: "/run/current-system/sw/bin/${c}") [
        "nixos-rebuild" "systemctl" "journalctl" "nix-collect-garbage"
      ];
      description = "The only commands the admin may run with sudo (password required).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.user != owner;
      message = "customConfig.services.remoteAdmin.user must differ from the primary user.";
    }];

    sops.secrets."${cfg.user}-password-hash" = {
      sopsFile = cfg.passwordSopsFile;
      neededForUsers = true;
    };

    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "${cfg.displayName} (remote admin)";
      extraGroups = [ ];   # not wheel: sudo comes only from the allowlist below
      hashedPasswordFile = config.sops.secrets."${cfg.user}-password-hash".path;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    security.sudo.extraRules = [{
      users = [ cfg.user ];
      commands = map (command: { inherit command; options = [ "PASSWD" ]; }) cfg.sudoCommands;
    }];

    services.openssh = {
      enable = true;
      openFirewall = false;   # opened on cfg.interface only, below
      settings = {
        AllowUsers = [ cfg.user ];
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        ClientAliveInterval = 60;
        ClientAliveCountMax = 3;
      };
    };
    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts =
      config.services.openssh.ports;

    security.pam.services.sshd.rules.session.remote-admin-notify = {
      order = 99999;   # after the session is set up
      control = "optional";
      modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
      args = [ "quiet" "${notifyOwner}" ];
    };
  };
}
