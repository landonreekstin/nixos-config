# ~/nixos-config/modules/home-manager/themes/windows7-xfce/xfconf.nix
{ config, pkgs, lib, customConfig, ... }:

# XFCE-authoritative theme settings, written as the xfconf per-channel XML that
# xfsettingsd/xfwm4 read. These are plain-value overrides of the whole files the
# functional base seeds with lib.mkDefault (plain value > mkDefault, so the theme wins).
# Whole-file replacement is the theme layer of the functional-vs-theme paradigm applied at
# xfconf granularity.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  xfconfDir = "xfce4/xfconf/xfce-perchannel-xml";

  # Windows 7 window chrome: B00merang xfwm4 decorations, app-menu icon on the left,
  # minimize/maximize/close on the right (O|HMC), centered title.
  xfwm4Xml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfwm4" version="1.0">
      <property name="general" type="empty">
        <property name="theme" type="string" value="Windows-7"/>
        <property name="title_alignment" type="string" value="center"/>
        <property name="button_layout" type="string" value="O|HMC"/>
        <property name="workspace_count" type="int" value="4"/>
        <property name="snap_to_border" type="bool" value="true"/>
        <property name="snap_to_windows" type="bool" value="true"/>
        <property name="show_app_icon" type="bool" value="true"/>
      </property>
    </channel>
  '';

  # GTK theme, "Windows 7 Aero" icons, Segoe UI, and the aero-drop cursor.
  # Event sounds enabled in M4.
  xsettingsXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xsettings" version="1.0">
      <property name="Net" type="empty">
        <property name="ThemeName" type="string" value="Windows-7"/>
        <property name="IconThemeName" type="string" value="Windows 7 Aero"/>
        <property name="EnableEventSounds" type="bool" value="false"/>
        <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
      </property>
      <property name="Gtk" type="empty">
        <property name="FontName" type="string" value="Segoe UI 9"/>
        <property name="CursorThemeName" type="string" value="aero-drop"/>
        <property name="CursorThemeSize" type="int" value="24"/>
      </property>
    </channel>
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = {
      "${xfconfDir}/xfwm4.xml".text = xfwm4Xml;
      "${xfconfDir}/xsettings.xml".text = xsettingsXml;
    };
  };
}
