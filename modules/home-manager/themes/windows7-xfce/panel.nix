# ~/nixos-config/modules/home-manager/themes/windows7-xfce/panel.nix
{ config, pkgs, lib, customConfig, ... }:

# The Windows 7 taskbar, generated from customConfig.homeManager.themes.xfcePanel so the
# pinned apps / tray applets / icon size are declarative per host (the Win7 analog of the
# KDE pinnedApps + systemTray config).
#
# Layout (left→right): Start orb (whiskermenu) · pinned icon-only launchers · window list
# (open apps, with labels) · expanding spacer · volume · systray (wifi/bluetooth applets) ·
# clock · show-desktop. Volume sits to the LEFT of the systray (which holds the wifi applet).
#
# Plugin ids: 1 = whiskermenu; 10.. = pinned launchers; 2 tasklist, 3 spacer, 4 pulseaudio,
# 5 systray, 6 clock, 7 showdesktop.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  panelCfg = customConfig.homeManager.themes.xfcePanel;
  pins = panelCfg.pinnedApps;
  trays = panelCfg.trayApplets;

  orb = "${config.home.homeDirectory}/.local/share/windows7-xfce/orb.png";

  # Stable per-launcher desktop-file id + panel plugin id.
  deskId = app: lib.toLower (lib.replaceStrings [ " " "/" ] [ "-" "-" ] app.name);
  launcherId = i: 10 + i;
  launcherIds = lib.imap0 (i: _: launcherId i) pins;
  # id 8 = a small transparent spacer between the Start orb and the pinned launchers.
  allIds = [ 1 8 ] ++ launcherIds ++ [ 2 3 4 5 6 7 ];

  pluginIdsXml = lib.concatMapStrings
    (id: "            <value type=\"int\" value=\"${toString id}\"/>\n") allIds;

  # One launcher plugin per pinned app (single item → shows just its icon).
  launcherPluginsXml = lib.concatStrings (lib.imap0 (i: app: ''
            <property name="plugin-${toString (launcherId i)}" type="string" value="launcher">
              <property name="items" type="array">
                <value type="string" value="${deskId app}.desktop"/>
              </property>
              <property name="disable-tooltips" type="bool" value="false"/>
              <property name="show-label" type="bool" value="false"/>
            </property>
  '') pins);

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
          <property name="icon-size" type="uint" value="${toString panelCfg.iconSize}"/>
          <property name="size" type="uint" value="40"/>
          <property name="plugin-ids" type="array">
    ${pluginIdsXml}      </property>
        </property>
      </property>
      <property name="plugins" type="empty">
        <property name="plugin-1" type="string" value="whiskermenu"/>
        <property name="plugin-8" type="string" value="separator">
          <property name="expand" type="bool" value="false"/>
          <property name="style" type="uint" value="0"/>
        </property>
    ${launcherPluginsXml}    <property name="plugin-2" type="string" value="tasklist">
          <property name="grouping" type="uint" value="1"/>
          <property name="show-labels" type="bool" value="true"/>
          <property name="flat-buttons" type="bool" value="false"/>
          <property name="show-handle" type="bool" value="false"/>
        </property>
        <property name="plugin-3" type="string" value="separator">
          <property name="expand" type="bool" value="true"/>
          <property name="style" type="uint" value="0"/>
        </property>
        <property name="plugin-4" type="string" value="pulseaudio">
          <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
          <property name="show-notifications" type="bool" value="true"/>
        </property>
        <property name="plugin-5" type="string" value="systray">
          <property name="square-icons" type="bool" value="true"/>
          <property name="icon-size" type="int" value="${toString panelCfg.iconSize}"/>
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
    search-actions=5
  '';

  # Each pinned app becomes a .desktop file in its launcher-<id> directory.
  launcherFiles = lib.listToAttrs (lib.imap0 (i: app: {
    name = "xfce4/panel/launcher-${toString (launcherId i)}/${deskId app}.desktop";
    value.text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=${app.name}
      Exec=${app.exec}
      Icon=${app.icon}
      Terminal=false
      StartupNotify=true
    '';
  }) pins);

  # Autostart the requested status-notifier applets into the systray.
  trayCmd = {
    network = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
    bluetooth = "${pkgs.blueman}/bin/blueman-applet";
  };
  trayFiles = lib.listToAttrs (map (t: {
    name = "autostart/win7-tray-${t}.desktop";
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 tray: ${t}
      Exec=${trayCmd.${t}}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  }) trays);
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = lib.mkMerge [
      launcherFiles
      trayFiles
      {
        "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml".text = panelXml;
        "xfce4/panel/whiskermenu-1.rc".text = whiskerRc;
      }
    ];
  };
}
