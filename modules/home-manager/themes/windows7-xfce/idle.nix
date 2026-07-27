# ~/nixos-config/modules/home-manager/themes/windows7-xfce/idle.nix
{ config, pkgs, lib, customConfig, ... }:

# Screensaver / lock / display-off timing for XFCE, driven by customConfig.desktop.idle
# (the same options KDE/Hyprland consume): screensaver activates at idle.screensaverTimeout,
# the screen locks at idle.lockTimeout, and the display powers off (DPMS) at idle.sleepTimeout.
# xfce4-screensaver and xfce4-power-manager both honor idle inhibitors, so media playback
# (browsers/mpv) and most fullscreen games automatically hold the screensaver/DPMS off.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  idle = customConfig.desktop.idle;
  toMin = s: builtins.floor (s / 60.0);

  # Saver stage: use screensaverTimeout if set, else fall back to lockTimeout.
  saverSecs = if idle.screensaverTimeout != null then idle.screensaverTimeout else idle.lockTimeout;
  saverMin = if saverSecs != null then toMin saverSecs else 15;
  # Lock happens lockTimeout - saver minutes AFTER the saver activates.
  lockEnabled = idle.lockTimeout != null;
  lockDelayMin = if lockEnabled && saverSecs != null
                 then lib.max 0 (toMin (idle.lockTimeout - saverSecs))
                 else 0;
  dpmsOffMin = if idle.sleepTimeout != null then toMin idle.sleepTimeout else 0;

  screensaverXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-screensaver" version="1.0">
      <property name="saver" type="empty">
        <property name="mode" type="int" value="0"/>
        <property name="idle-activation" type="empty">
          <property name="enabled" type="bool" value="true"/>
          <property name="delay" type="int" value="${toString saverMin}"/>
        </property>
      </property>
      <property name="lock" type="empty">
        <property name="enabled" type="bool" value="${lib.boolToString lockEnabled}"/>
        <property name="saver-activation" type="empty">
          <property name="enabled" type="bool" value="${lib.boolToString lockEnabled}"/>
          <property name="delay" type="int" value="${toString lockDelayMin}"/>
        </property>
      </property>
    </channel>
  '';

  powerXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-power-manager" version="1.0">
      <property name="xfce4-power-manager" type="empty">
        <property name="dpms-enabled" type="bool" value="${lib.boolToString (dpmsOffMin > 0)}"/>
        <property name="dpms-on-ac-sleep" type="uint" value="0"/>
        <property name="dpms-on-ac-off" type="uint" value="${toString dpmsOffMin}"/>
        <property name="blank-on-ac" type="int" value="0"/>
        <property name="lock-screen-suspend-hibernate" type="bool" value="true"/>
      </property>
    </channel>
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = {
      "xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml".text = screensaverXml;
      "xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml".text = powerXml;
    };
  };
}
