# ~/nixos-config/modules/nixos/desktop/xfce.nix
{ config, pkgs, lib, ... }:

# XFCE — the only X11 desktop in this flake. Added as a coexisting login-session
# choice alongside the Wayland DEs (KDE/Hyprland/COSMIC): rock-solid on NVIDIA and a
# well-shaped canvas for the windows7 theme (xfwm4 = themable window decorations,
# xfce4-panel = a real taskbar). Keep xfwm4 — the Win7 decorations depend on it.
let
  # The windows7 XFCE theme uses xscreensaver for its screensaver + lock (xfce4-screensaver's
  # saver engine can't render on NixOS). xscreensaver's PAM auth helper must be setuid root to
  # verify the unlock password — otherwise it prints "Password initialization failed" and the
  # screen can never be unlocked. This is a system-level concern (setuid wrapper + PAM), so it
  # lives here rather than in the home-manager theme.
  win7Xfce = config.customConfig.homeManager.themes.xfce == "windows7";
in
{
  config = lib.mkIf (lib.elem "xfce" config.customConfig.desktop.environments) {

    services.xserver.enable = true;
    services.xserver.desktopManager.xfce.enable = true;

    # xscreensaver unlock: setuid auth helper + PAM service (only when the windows7 theme,
    # which enables xscreensaver, is selected). xscreensaver launches "xscreensaver-auth" by
    # name via PATH, so the /run/wrappers/bin setuid copy wins over its non-setuid libexec one.
    security.wrappers.xscreensaver-auth = lib.mkIf win7Xfce {
      owner = "root";
      group = "root";
      setuid = true;
      source = "${pkgs.xscreensaver}/libexec/xscreensaver/xscreensaver-auth";
    };
    security.pam.services.xscreensaver = lib.mkIf win7Xfce { enable = true; };

    # NIXOS_OZONE_WL=1 is set globally (hyprland.nix) as a Wayland hint, but it leaks into
    # this X11 session and breaks Electron apps whose wrappers unset DISPLAY when they see it
    # (e.g. Spotify won't launch). Reset it for the X11 session so Electron apps use X11.
    services.xserver.displayManager.sessionCommands = "export NIXOS_OZONE_WL=0";

    # GTK portal for XFCE (file pickers, screenshots, etc.).
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    };

    # Core XFCE (panel, thunar, xfconf, settings, notifyd) comes from the
    # desktopManager module above. These are the extras the windows7 theme builds on
    # (whiskermenu Start menu, audio/tray plugins) plus general niceties.
    # pipewire is provided globally by modules/nixos/common/audio.nix.
    environment.systemPackages = with pkgs; [
      xfce.xfce4-whiskermenu-plugin
      xfce.xfce4-pulseaudio-plugin
      xfce.xfce4-screenshooter
      networkmanagerapplet
    ];

  };
}
