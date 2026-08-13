# ~/nixos-config/modules/nixos/desktop/xrdp.nix
{ config, pkgs, lib, ... }:

# Remote-desktop server, exposed via customConfig.desktop.xrdp (sibling to desktop.wayvnc).
# Lets a desktop session (XFCE on gaming-pc) be reached over RDP for remote theme work.
#
# xrdp runs its own per-session X backend (xorgxrdp), independent of the local NVIDIA
# seat-0 Xorg/Ly login, so it coexists with the physical KDE/Hyprland session with no
# display-manager changes. XFCE is available because desktop/xfce.nix already sets
# services.xserver.desktopManager.xfce.enable when "xfce" is in desktop.environments.
#
# Private by default: openFirewall stays off, so reach it over an SSH tunnel
# (`ssh -L 3389:localhost:3389 lando@<host>`), matching the desktop.wayvnc posture.
#
# GOTCHA: NixOS does NOT auto-restart xrdp-sesman on a config switch (restarting it would
# kill live sessions), so after changing this module a `rebuild` alone keeps serving the OLD
# session wrapper until `sudo systemctl restart xrdp-sesman` (or a reboot). This does not
# affect theme iteration — an RDP reconnect picks up rebuilt XFCE config fine; it only
# matters when you change xrdp itself.
let
  cfg = config.customConfig.desktop.xrdp;

  # windowManager must be the DE *launcher* (startxfce4), not the bare session binary
  # (xfce4-session): the launcher sets up the XDG_* env the bare binary needs.
  sessionCmd = pkgs.writeShellScript "xrdp-session" ''
    # xrdp provides no Xsession wrapper, so send session output where a display manager
    # normally would — makes startup failures diagnosable (HOME is set by the PAM session).
    exec > "$HOME/.xsession-errors" 2>&1

    # xfce.nix resets NIXOS_OZONE_WL=0 via services.xserver.displayManager.sessionCommands,
    # which only runs for DM-launched local logins — xrdp sessions don't inherit it. Re-assert
    # it so Electron autostarts (vesktop, etc.) stay on X11 in the remote session.
    export NIXOS_OZONE_WL=0

    # Force a PRIVATE D-Bus session bus. If the same user is also logged in on the physical
    # seat, the remote session would otherwise discover the shared /run/user/$UID/bus and
    # xfce4-session bails immediately (a second graphical session can't attach to it). A
    # private bus decouples the two sessions and gives the remote one its own xfconfd, so the
    # seeded theme applies independently.
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${cfg.windowManager} "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.xrdp = {
      enable = true;
      defaultWindowManager = "${sessionCmd}";
      openFirewall = cfg.openFirewall;
    };

    # The RDP login authenticates through the xrdp-sesman PAM stack, which — unlike ly — does
    # not unlock gnome-keyring. So the login keyring stays locked in the remote session and
    # nm-applet's WiFi-secret lookup pops "the login keyring did not get entered…". Load the
    # gnome-keyring PAM module into xrdp-sesman so the password typed at the RDP prompt unlocks
    # it, mirroring security.pam.services.ly.enableGnomeKeyring for the physical login.
    services.gnome.gnome-keyring.enable = true;                 # already true via ly on gaming-pc; keeps the module self-contained
    security.pam.services.xrdp-sesman.enableGnomeKeyring = true;
  };
}
