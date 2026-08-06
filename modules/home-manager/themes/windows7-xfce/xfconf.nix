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

  # GTK theme / icon / cursor names, shared by the seeded xsettings.xml and the login
  # re-assert below so they can never drift apart.
  gtkThemeName = "Windows-7";
  iconThemeName = "Windows 7 Aero";
  cursorThemeName = "aero-drop";

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
        <!-- Aero Snap: drag to a screen edge => half, into a corner => quadrant,
             to the top => maximize. Keyboard equivalents live in keybindings.nix.
             tile_on_move is already xfwm4's default; wrap_windows (also default-on)
             competes for the same edge gesture by wrapping the window to the adjacent
             workspace, so disable it — Windows 7 has no drag-to-next-desktop behavior. -->
        <property name="tile_on_move" type="bool" value="true"/>
        <property name="wrap_windows" type="bool" value="false"/>
      </property>
    </channel>
  '';

  # GTK theme, "Windows 7 Aero" icons, Segoe UI, and the aero-drop cursor.
  # Event sounds enabled in M4.
  xsettingsXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xsettings" version="1.0">
      <property name="Net" type="empty">
        <property name="ThemeName" type="string" value="${gtkThemeName}"/>
        <property name="IconThemeName" type="string" value="${iconThemeName}"/>
        <property name="SoundThemeName" type="string" value="Windows 7"/>
        <property name="EnableEventSounds" type="bool" value="true"/>
        <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
      </property>
      <property name="Gtk" type="empty">
        <property name="FontName" type="string" value="Segoe UI 9"/>
        <property name="CursorThemeName" type="string" value="${cursorThemeName}"/>
        <property name="CursorThemeSize" type="int" value="24"/>
      </property>
    </channel>
  '';

  # Per-session re-assert of the Win7 GTK theme / icons / cursor.
  #
  # On multi-DE hosts the Hyprland theme (century-series) sets the *global* home-manager
  # gtk.* options (Adwaita-dark / Papirus-Dark / Adwaita), which land in ~/.config/gtk-3.0/
  # settings.ini. At XFCE session start, xfsettingsd reads that once and syncs it into the
  # xsettings channel — clobbering the seeded Win7 values above (Sound/Font survive because
  # they aren't in that synced set). xfsettingsd only does this at startup and respects later
  # xfconf changes, so an autostart re-assert makes Win7 win in the XFCE session. It writes
  # ONLY the xsettings channel (not gsettings), so the global/Hyprland look is untouched.
  reassertScript = pkgs.writeShellScript "win7-xfce-reassert-gtk" ''
    xq=${pkgs.xfce.xfconf}/bin/xfconf-query
    # xfsettingsd clobbers within the first moment of the session; re-assert across a short
    # window so we win regardless of exact startup timing.
    for _ in $(seq 1 8); do
      "$xq" -c xsettings -p /Net/ThemeName     -s "${gtkThemeName}"   2>/dev/null || true
      "$xq" -c xsettings -p /Net/IconThemeName -s "${iconThemeName}"  2>/dev/null || true
      "$xq" -c xsettings -p /Gtk/CursorThemeName -s "${cursorThemeName}" 2>/dev/null || true
      sleep 1
    done
  '';
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = {
      "${xfconfDir}/xfwm4.xml".text = xfwm4Xml;
      "${xfconfDir}/xsettings.xml".text = xsettingsXml;

      "autostart/win7-reassert-gtk.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Windows 7 GTK theme re-assert
        Exec=${reassertScript}
        OnlyShowIn=XFCE;
        X-XFCE-Autostart-enabled=true
      '';
    };
  };
}
