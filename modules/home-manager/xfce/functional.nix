# ~/nixos-config/modules/home-manager/xfce/functional.nix
{ lib, config, pkgs, customConfig, ... }:

# Always-on functional base for the XFCE desktop (mirrors hyprland/kde functional
# modules). Owns autostart generation and the base xfconf seed. Everything here uses
# lib.mkDefault (or writes whole XML files the theme can replace) so the windows7-xfce
# theme can override cleanly.
#
# xfconf note: home-manager has no xfconf module, so settings are seeded as the
# per-channel XML files XFCE reads at ~/.config/xfce4/xfconf/xfce-perchannel-xml/.
# On first session these are authoritative; xfconfd then owns them at runtime (so user
# tweaks persist). The windows7-xfce theme's `xfceOverride` toggle wipes this dir on
# each switch when strict re-assertion is wanted.
let
  isXfceDesktop = customConfig.desktop.enable
    && lib.elem "xfce" customConfig.desktop.environments;

  xfceAutostart = lib.filter (app:
    app.desktops == [] || lib.elem "xfce" app.desktops
  ) customConfig.desktop.autostart;

  # Reuse the KDE autostart-entry shape (minus the KDE-specific phase key). XFCE reads
  # the same ~/.config/autostart/*.desktop XDG mechanism.
  mkDesktopEntry = app:
    let
      name = lib.last (lib.splitString "/" (lib.head (lib.splitString " " app.command)));
    in {
      name = "autostart/${name}.desktop";
      value.text = ''
        [Desktop Entry]
        Type=Application
        Exec=${app.command}
        Name=${name}
      '';
    };

  xfconfDir = "xfce4/xfconf/xfce-perchannel-xml";

  # XFCE default web browser (exo helper layer). On XFCE, xdg-open/xdg-settings route through
  # xfce4-web-browser.desktop -> `exo-open --launch WebBrowser`, which reads helpers.rc, NOT
  # mimeapps.list. Point it at the host's chosen default browser via a custom helper so the
  # exo path matches the generic mimeapps.list default (system/xdg.nix). gtk-launch dispatches
  # by .desktop id, so this works for native and flatpak browsers and tracks apps.defaults.
  browserDesktop = customConfig.apps.defaults.${customConfig.apps.defaultSet}.browser;
  browserId = lib.removeSuffix ".desktop" browserDesktop;

  webBrowserHelper = ''
    [Desktop Entry]
    NoDisplay=true
    Version=1.0
    Encoding=UTF-8
    Type=X-XFCE-Helper
    X-XFCE-Category=WebBrowser
    Name=Default Browser
    Icon=${browserId}
    X-XFCE-Commands=${pkgs.gtk3}/bin/gtk-launch ${browserId}
    X-XFCE-CommandsWithParameter=${pkgs.gtk3}/bin/gtk-launch ${browserId} "%s"
  '';

  # Base xsettings: neutral GTK/icon/cursor defaults. The theme overrides this whole file.
  xsettingsXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xsettings" version="1.0">
      <property name="Net" type="empty">
        <property name="ThemeName" type="string" value="Adwaita"/>
        <property name="IconThemeName" type="string" value="Adwaita"/>
        <property name="EnableEventSounds" type="bool" value="false"/>
        <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
      </property>
      <property name="Gtk" type="empty">
        <property name="FontName" type="string" value="Sans 10"/>
        <property name="CursorThemeName" type="string" value="default"/>
      </property>
    </channel>
  '';

  # Base window manager settings: stock theme, sane button layout. The theme overrides
  # the `theme` (and button layout / alignment) to the Win7 xfwm4 decorations.
  xfwm4Xml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfwm4" version="1.0">
      <property name="general" type="empty">
        <property name="theme" type="string" value="Default"/>
        <property name="title_alignment" type="string" value="center"/>
        <property name="button_layout" type="string" value="O|SHMC"/>
        <property name="workspace_count" type="int" value="4"/>
        <property name="snap_to_border" type="bool" value="true"/>
        <property name="snap_to_windows" type="bool" value="true"/>
      </property>
    </channel>
  '';
in
{
  config = lib.mkIf isXfceDesktop {
    # Autostart entries (XDG) generated from customConfig.desktop.autostart.
    # Base xfconf seeds use mkDefault so the windows7-xfce theme replaces the whole file.
    xdg.configFile = lib.mkMerge [
      (lib.listToAttrs (map mkDesktopEntry xfceAutostart))
      {
        "${xfconfDir}/xsettings.xml".text = lib.mkDefault xsettingsXml;
        "${xfconfDir}/xfwm4.xml".text = lib.mkDefault xfwm4Xml;
        # exo's preferred WebBrowser -> the custom helper written below.
        "xfce4/helpers.rc".text = lib.mkDefault "WebBrowser=custom-WebBrowser\n";
      }
    ];

    # Custom exo WebBrowser helper launching the host default browser (see note above).
    xdg.dataFile."xfce4/helpers/custom-WebBrowser.desktop".text = webBrowserHelper;
  };
}
