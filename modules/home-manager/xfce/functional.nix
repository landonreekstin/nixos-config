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
      }
    ];
  };
}
