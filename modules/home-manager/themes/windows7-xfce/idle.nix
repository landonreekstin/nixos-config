# ~/nixos-config/modules/home-manager/themes/windows7-xfce/idle.nix
{ config, pkgs, lib, customConfig, ... }:

# Display-off (DPMS) timing for XFCE, driven by customConfig.desktop.idle. The screensaver
# visual + lock are owned by xscreensaver (see ./screensaver.nix) because xfce4-screensaver's
# saver engine can't render anything on NixOS; xfce4-screensaver is disabled there. DPMS is
# owned by xscreensaver too (it clobbers xset DPMS on activate), so this file DISABLES
# xfce4-power-manager's DPMS and neuters the xfce4-screensaver xfconf channel as
# belt-and-suspenders (in case either daemon ever starts, it must not race xscreensaver).
#
# power-button-action is pinned to 0 (XFPM_DO_NOTHING, also upstream's default) on purpose.
# xfce4-power-manager XGrabKey()s XF86PowerOff on the root window unconditionally at startup
# (src/xfpm-button.c), racing xfsettingsd for the same grab — and the loser silently gets
# nothing. keybindings.nix binds XF86PowerOff to the power flyout, so xfsettingsd winning
# (the normal case: it starts with the session core, xfpm only later from the tray autostart)
# opens the flyout. Pinning this to 0 makes the *other* outcome harmless rather than an
# unguarded poweroff: whoever wins, the power button either shows the flyout or does nothing.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # Neutered: xscreensaver owns the saver + lock, so xfce4-screensaver must do nothing.
  screensaverXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-screensaver" version="1.0">
      <property name="saver" type="empty">
        <property name="mode" type="int" value="0"/>
        <property name="idle-activation" type="empty">
          <property name="enabled" type="bool" value="false"/>
        </property>
      </property>
      <property name="lock" type="empty">
        <property name="enabled" type="bool" value="false"/>
        <property name="saver-activation" type="empty">
          <property name="enabled" type="bool" value="false"/>
        </property>
      </property>
    </channel>
  '';

  powerXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-power-manager" version="1.0">
      <property name="xfce4-power-manager" type="empty">
        <property name="dpms-enabled" type="bool" value="false"/>
        <property name="blank-on-ac" type="int" value="0"/>
        <property name="lock-screen-suspend-hibernate" type="bool" value="true"/>
        <property name="power-button-action" type="int" value="0"/>
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
