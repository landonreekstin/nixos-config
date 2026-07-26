# ~/nixos-config/modules/home-manager/themes/windows7-xfce/panel.nix
{ config, pkgs, lib, customConfig, ... }:

# The Windows 7 taskbar: a single locked bottom panel with the Start orb
# (whiskermenu), grouped window buttons, a spacer, the system tray, a two-line clock,
# and the far-right show-desktop sliver. Written as whole-file xfconf XML plus the
# whiskermenu rc. Panel plugin numbering: 1 whiskermenu, 2 tasklist, 3 separator(expand),
# 4 systray, 5 clock, 6 showdesktop.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  orb = "${config.home.homeDirectory}/.local/share/windows7-xfce/orb.png";

  panelXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-panel" version="1.0">
      <property name="configver" type="int" value="2"/>
      <property name="panels" type="array">
        <value type="int" value="1"/>
        <property name="dark-mode" type="bool" value="true"/>
        <property name="panel-1" type="empty">
          <property name="position" type="string" value="p=8;x=0;y=0"/>
          <property name="length" type="uint" value="100"/>
          <property name="position-locked" type="bool" value="true"/>
          <property name="icon-size" type="uint" value="36"/>
          <property name="size" type="uint" value="40"/>
          <property name="plugin-ids" type="array">
            <value type="int" value="1"/>
            <value type="int" value="2"/>
            <value type="int" value="3"/>
            <value type="int" value="4"/>
            <value type="int" value="5"/>
            <value type="int" value="6"/>
            <value type="int" value="7"/>
          </property>
        </property>
      </property>
      <property name="plugins" type="empty">
        <property name="plugin-1" type="string" value="whiskermenu"/>
        <property name="plugin-2" type="string" value="tasklist">
          <property name="grouping" type="uint" value="1"/>
          <property name="show-labels" type="bool" value="true"/>
          <property name="flat-buttons" type="bool" value="false"/>
          <property name="show-handle" type="bool" value="false"/>
        </property>
        <property name="plugin-3" type="string" value="separator">
          <property name="expand" type="bool" value="true"/>
          <property name="style" type="uint" value="0"/>
        </property>
        <property name="plugin-4" type="string" value="systray">
          <property name="square-icons" type="bool" value="true"/>
        </property>
        <property name="plugin-5" type="string" value="pulseaudio">
          <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
          <property name="show-notifications" type="bool" value="true"/>
        </property>
        <property name="plugin-6" type="string" value="clock">
          <property name="mode" type="uint" value="2"/>
          <property name="digital-layout" type="uint" value="3"/>
          <property name="digital-time-format" type="string" value="%-I:%M %p"/>
          <property name="digital-date-format" type="string" value="%-m/%-d/%Y"/>
        </property>
        <property name="plugin-7" type="string" value="showdesktop"/>
      </property>
    </channel>
  '';

  # Whiskermenu (Start menu) — Win7 orb button, no text label, search + favorites.
  whiskerRc = ''
    button-title=Start
    button-icon=${orb}
    button-single-row=false
    show-button-title=false
    show-button-icon=true
    launcher-show-name=true
    launcher-show-description=true
    launcher-show-tooltip=true
    category-show-name=true
    item-icon-size=2
    category-icon-size=1
    load-hierarchy=false
    view-as-icons=false
    default-category=0
    recent-items-count=10
    favorites-in-recent=true
    position-search-alternate=true
    position-commands-alternate=false
    position-categories-alternate=true
    stay-focused=false
    confirm-session-command=true
    menu-width=450
    menu-height=550
    menu-opacity=100
    command-settings=xfce4-settings-manager
    show-command-settings=true
    command-lockscreen=xflock4
    show-command-lockscreen=true
    command-logout=xfce4-session-logout
    show-command-logout=true
    command-menueditor=menulibre
    show-command-menueditor=false
    command-profile=mugshot
    show-command-profile=false
    search-actions=5
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = {
      "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml".text = panelXml;
      "xfce4/panel/whiskermenu-1.rc".text = whiskerRc;
    };
  };
}
