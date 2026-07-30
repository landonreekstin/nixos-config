# ~/nixos-config/modules/home-manager/themes/windows7-xfce/panel.nix
{ config, pkgs, lib, customConfig, ... }:

# The Windows 7 taskbar, generated from customConfig.homeManager.themes.xfcePanel so the
# pinned apps / tray applets / icon size are declarative per host (the Win7 analog of the
# KDE pinnedApps + systemTray config).
#
# Multi-monitor: XFCE can't span one panel across outputs, so we generate ONE panel per
# enabled monitor (customConfig.desktop.monitors). Every panel is a full clone — Start orb ·
# pinned launchers · window list · clock · show-desktop — but the system tray + volume live
# only on the PRIMARY panel (status-notifier icons can register to just one host). Panels are
# bound to their monitor by EDID at login (bind-outputs script) so they follow the right
# physical screen even when connector names reorder across reboots — mirroring the layout
# resolver in modules/home-manager/xfce/monitors.nix. Hosts with no desktop.monitors get a
# single full panel (previous behaviour).
#
# Layout (left→right): Start orb (whiskermenu) · pinned icon-only launchers · window list
# (open apps, with labels) · expanding spacer · [volume · systray — primary only] · clock ·
# show-desktop.
#
# Per-panel plugin ids are namespaced by panel index p as base = p*100 (panel 0 keeps the
# familiar 1/8/10../2-7 ids): 1 whiskermenu · 8 separator · 10.. launchers · 2 tasklist ·
# 3 spacer · 4 pulseaudio · 5 systray · 6 clock · 7 showdesktop.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  panelCfg = customConfig.homeManager.themes.xfcePanel;
  pins = panelCfg.pinnedApps;
  trays = panelCfg.trayApplets;

  orb = "${config.home.homeDirectory}/.local/share/windows7-xfce/orb.png";

  # Stable per-launcher desktop-file id.
  deskId = app: lib.toLower (lib.replaceStrings [ " " "/" ] [ "-" "-" ] app.name);

  isDesc = id: lib.hasPrefix "desc:" id || lib.hasInfix " " id;

  # One panel per enabled monitor; fall back to a single (primary) panel when none configured.
  enabledMons = lib.filter (m: m.enabled) customConfig.desktop.monitors;
  panelMons = if enabledMons != [] then enabledMons else [ null ];
  indexedMons = lib.imap0 (i: m: { inherit i m; }) panelMons;
  primaryIndex =
    let mains = lib.filter (e: e.m != null && e.m.name == "main") indexedMons;
    in if mains != [] then (lib.head mains).i else 0;

  # ---- Per-panel fragment builders -------------------------------------------------------
  panelBase = i: i * 100;

  panelPluginIds = { i, m }:
    let
      base = panelBase i;
      isPrim = i == primaryIndex;
      launcherIds = lib.imap0 (j: _: base + 10 + j) pins;
    in
    [ (base + 1) (base + 8) ] ++ launcherIds ++ [ (base + 2) (base + 3) ]
    ++ lib.optionals isPrim [ (base + 4) (base + 5) ]
    ++ [ (base + 6) (base + 7) ];

  # <panel-N> property block (geometry + plugin-id list). output-name is seeded by the
  # bind-outputs login script, not here.
  mkPanelBlock = { i, m }:
    let
      num = toString (i + 1);
      idsXml = lib.concatMapStrings
        (id: "            <value type=\"int\" value=\"${toString id}\"/>\n")
        (panelPluginIds { inherit i m; });
    in ''
        <property name="panel-${num}" type="empty">
          <property name="position" type="string" value="p=8;x=0;y=0"/>
          <property name="length" type="uint" value="100"/>
          <property name="position-locked" type="bool" value="true"/>
          <property name="icon-size" type="uint" value="${toString panelCfg.iconSize}"/>
          <property name="size" type="uint" value="40"/>
          <property name="plugin-ids" type="array">
    ${idsXml}      </property>
        </property>
    '';

  # Plugin definitions for one panel.
  mkPanelPlugins = { i, m }:
    let
      base = panelBase i;
      isPrim = i == primaryIndex;
      launcherPluginsXml = lib.concatStrings (lib.imap0 (j: app: ''
            <property name="plugin-${toString (base + 10 + j)}" type="string" value="launcher">
              <property name="items" type="array">
                <value type="string" value="${deskId app}.desktop"/>
              </property>
              <property name="disable-tooltips" type="bool" value="false"/>
              <property name="show-label" type="bool" value="false"/>
            </property>
      '') pins);
      trayPluginsXml = lib.optionalString isPrim ''
        <property name="plugin-${toString (base + 4)}" type="string" value="pulseaudio">
          <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
          <property name="show-notifications" type="bool" value="true"/>
        </property>
        <property name="plugin-${toString (base + 5)}" type="string" value="systray">
          <property name="square-icons" type="bool" value="true"/>
          <property name="icon-size" type="int" value="${toString panelCfg.iconSize}"/>
        </property>
      '';
    in ''
        <property name="plugin-${toString (base + 1)}" type="string" value="whiskermenu"/>
        <property name="plugin-${toString (base + 8)}" type="string" value="separator">
          <property name="expand" type="bool" value="false"/>
          <property name="style" type="uint" value="0"/>
        </property>
    ${launcherPluginsXml}    <property name="plugin-${toString (base + 2)}" type="string" value="tasklist">
          <property name="grouping" type="uint" value="1"/>
          <property name="show-labels" type="bool" value="true"/>
          <property name="flat-buttons" type="bool" value="false"/>
          <property name="show-handle" type="bool" value="false"/>
        </property>
        <property name="plugin-${toString (base + 3)}" type="string" value="separator">
          <property name="expand" type="bool" value="true"/>
          <property name="style" type="uint" value="0"/>
        </property>
    ${trayPluginsXml}    <property name="plugin-${toString (base + 6)}" type="string" value="clock">
          <property name="mode" type="uint" value="2"/>
          <property name="digital-layout" type="uint" value="3"/>
          <property name="digital-time-format" type="string" value="%-I:%M %p"/>
          <property name="digital-date-format" type="string" value="%-m/%-d/%Y"/>
        </property>
        <property name="plugin-${toString (base + 7)}" type="string" value="showdesktop"/>
    '';

  panelsListXml = lib.concatMapStrings
    (e: "        <value type=\"int\" value=\"${toString (e.i + 1)}\"/>\n") indexedMons;

  panelXml = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-panel" version="1.0">
      <property name="configver" type="int" value="2"/>
      <property name="panels" type="array">
    ${panelsListXml}    <property name="dark-mode" type="bool" value="true"/>
    ${lib.concatMapStrings mkPanelBlock indexedMons}  </property>
      <property name="plugins" type="empty">
    ${lib.concatMapStrings mkPanelPlugins indexedMons}  </property>
    </channel>
  '';

  # ── Windows-7 power flyout (the Start-menu "Shut Down" button) ───────────────────────────
  # The Start "Shut Down" button opens this tiny GTK flyout instead of the stock
  # xfce4-session-logout confirmation dialog, which on X11 swallowed the FIRST pointer click
  # (xfce4-session grabs the seat while a fadeout window fade-animates over the screen, so the
  # first click landed on the fade and was lost — the fadeout is hardcoded under ENABLE_X11 in
  # xfsm-logout-dialog.c with no xfconf toggle). The window inherits the Win7 GTK theme, so it
  # matches the rest of the desktop with no extra styling.
  #
  # The four session actions call the xfce4-session manager's D-Bus methods DIRECTLY on the
  # flyout's own session-bus connection (org.xfce.Session.Manager: Shutdown/Restart/Suspend/
  # Logout at /org/xfce/SessionManager). The earlier approach — spawning
  # `xfce4-session-logout --reboot/--halt/...` and immediately quitting — silently failed to
  # deliver in the local `ly` session (logind never saw the request; the manager itself was
  # healthy and CanRestart=true), while Lock kept working because xflock4 needs no manager
  # round-trip. Calling the manager directly is deterministic and still skips the fading
  # dialog (Logout is invoked with show_dialog=false). Lock stays on xflock4 (already works).
  sessionBin = "${pkgs.xfce.xfce4-session}/bin";
  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  powerMenuPy = pkgs.writeText "win7-power-menu.py" ''
    import gi, subprocess, sys
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib, Gio

    LOCK = "${sessionBin}/xflock4"

    BUS = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def mgr(method, params):
        BUS.call_sync("org.xfce.SessionManager", "/org/xfce/SessionManager",
                      "org.xfce.Session.Manager", method, params,
                      None, Gio.DBusCallFlags.NONE, -1, None)

    # allow_save=False mirrors the old `--fast` (no session save); Logout show_dialog=False
    # keeps the fading dialog (and its lost-first-click) out of the picture.
    ACTIONS = [
        ("Shut Down", "system-shutdown",    lambda: mgr("Shutdown", GLib.Variant("(b)", (False,)))),
        ("Restart",   "system-reboot",      lambda: mgr("Restart",  GLib.Variant("(b)", (False,)))),
        ("Sleep",     "system-suspend",     lambda: mgr("Suspend",  None)),
        ("Log Off",   "system-log-out",     lambda: mgr("Logout",   GLib.Variant("(bb)", (False, False)))),
        ("Lock",      "system-lock-screen", lambda: subprocess.Popen([LOCK])),
    ]

    class PowerMenu(Gtk.Window):
        def __init__(self):
            Gtk.Window.__init__(self, type=Gtk.WindowType.TOPLEVEL)
            self.set_title("Shut down")
            self.set_decorated(False)
            self.set_skip_taskbar_hint(True)
            self.set_skip_pager_hint(True)
            self.set_keep_above(True)
            self.set_resizable(False)
            self.set_type_hint(Gdk.WindowTypeHint.UTILITY)
            self.set_position(Gtk.WindowPosition.MOUSE)

            frame = Gtk.Frame()
            frame.set_shadow_type(Gtk.ShadowType.OUT)
            self.add(frame)
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
            box.set_border_width(2)
            frame.add(box)

            for label, icon, action in ACTIONS:
                btn = Gtk.Button()
                btn.set_relief(Gtk.ReliefStyle.NONE)
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                row.set_border_width(4)
                row.pack_start(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR),
                               False, False, 0)
                lbl = Gtk.Label(label=label)
                lbl.set_xalign(0.0)
                row.pack_start(lbl, True, True, 0)
                btn.add(row)
                btn.connect("clicked", self.on_click, action)
                box.pack_start(btn, False, False, 0)

            self._ready = False
            self.connect("key-press-event", self.on_key)
            self.connect("focus-out-event", self.on_focus_out)
            self.connect("destroy", Gtk.main_quit)
            # Ignore the spurious focus-out that can fire while the window first maps.
            GLib.timeout_add(300, self._enable_dismiss)

        def _enable_dismiss(self):
            self._ready = True
            return False

        def on_focus_out(self, *args):
            if self._ready:
                Gtk.main_quit()
            return False

        def on_key(self, widget, event):
            if event.keyval == Gdk.KEY_Escape:
                Gtk.main_quit()
            return False

        def on_click(self, button, action):
            self.hide()
            while Gtk.events_pending():
                Gtk.main_iteration()
            try:
                action()
            except Exception as exc:
                sys.stderr.write("win7-power-menu: " + str(exc) + "\n")
            Gtk.main_quit()

    def main():
        win = PowerMenu()
        win.show_all()
        win.present()
        Gtk.main()

    main()
  '';
  powerMenu = pkgs.stdenv.mkDerivation {
    name = "win7-power-menu";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pyEnv ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      { echo '#!${pyEnv}/bin/python3'; cat ${powerMenuPy}; } > $out/bin/win7-power-menu
      chmod +x $out/bin/win7-power-menu
      runHook postInstall
    '';
  };

  # Whiskermenu (Start menu) rc — one instance per panel (plugin id base+1). Win7 orb button.
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
    confirm-session-command=false
    menu-width=450
    menu-height=550
    menu-opacity=100
    command-settings=xfce4-settings-manager
    show-command-settings=true
    command-lockscreen=xflock4
    show-command-lockscreen=true
    command-logout=${powerMenu}/bin/win7-power-menu
    show-command-logout=true
    search-actions=5
  '';
  whiskerRcFiles = lib.listToAttrs (map (e: {
    name = "xfce4/panel/whiskermenu-${toString (panelBase e.i + 1)}.rc";
    value.text = whiskerRc;
  }) indexedMons);

  # Each pinned app becomes a .desktop file in its launcher-<id> directory, per panel.
  launcherFiles = lib.listToAttrs (lib.concatMap
    (e: lib.imap0 (j: app: {
      name = "xfce4/panel/launcher-${toString (panelBase e.i + 10 + j)}/${deskId app}.desktop";
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
    }) pins)
    indexedMons);

  # ---- Bind each panel to its monitor by EDID, at login ----------------------------------
  # JSON: [{panel, primary, selector, isDesc}] — selector is the EDID substring or connector.
  # Same edid-aware selector as the layout resolver: prefer `edid` (EDID match), else the
  # `identifier` (desc: → EDID match, or a plain connector name → literal).
  useEdid = m: m.edid != null && m.edid != "";
  monSelector = m:
    if useEdid m then m.edid
    else if isDesc m.identifier then lib.removePrefix "desc:" m.identifier
    else m.identifier;
  panelBindJson = pkgs.writeText "xfce-panel-bind.json" (builtins.toJSON (map (e: {
    panel = e.i + 1;
    primary = e.i == primaryIndex;
    selector = if e.m == null then "" else monSelector e.m;
    isDesc = e.m != null && (useEdid e.m || isDesc e.m.identifier);
  }) indexedMons));

  bindPy = pkgs.writeText "xfce-bind-panels.py" ''
    import json, re, subprocess, sys

    XRANDR = "${pkgs.xorg.xrandr}/bin/xrandr"
    XQ = "${pkgs.xfce.xfconf}/bin/xfconf-query"
    PANEL = "${pkgs.xfce.xfce4-panel}/bin/xfce4-panel"

    def parse_edid(hexstr):
        try:
            b = bytes.fromhex(hexstr)
        except ValueError:
            return ""
        if len(b) < 128:
            return ""
        mfg = (b[8] << 8) | b[9]
        letters = "".join(chr(((mfg >> s) & 0x1f) + 64) for s in (10, 5, 0))
        parts = [letters]
        for off in (54, 72, 90, 108):
            d = b[off:off + 18]
            if len(d) == 18 and d[0] == 0 and d[1] == 0 and d[2] == 0 and d[3] in (0xFC, 0xFF, 0xFE):
                txt = d[5:18].split(b"\n")[0].decode("ascii", "ignore").strip()
                if txt:
                    parts.append(txt)
        parts.append(str(int.from_bytes(b[12:16], "little")))
        return " ".join(parts)

    def get_outputs():
        try:
            out = subprocess.run([XRANDR, "--verbose"], capture_output=True, text=True).stdout
        except Exception:
            return {}
        outputs, cur, edid_mode, edid_hex = {}, None, False, []
        def flush():
            if cur is not None:
                outputs[cur]["edid"] = parse_edid("".join(edid_hex))
        for line in out.splitlines():
            m = re.match(r"^(\S+) (connected|disconnected)", line)
            if m:
                flush()
                edid_hex[:] = []
                edid_mode = False
                cur = m.group(1)
                outputs[cur] = {"connected": m.group(2) == "connected", "edid": ""}
                continue
            if cur is None:
                continue
            if re.match(r"^\s+EDID:", line):
                edid_mode = True
                continue
            if edid_mode:
                h = line.strip()
                if re.fullmatch(r"[0-9a-fA-F]+", h):
                    edid_hex.append(h)
                else:
                    edid_mode = False
        flush()
        return outputs

    def resolve(sel, is_desc, outputs, used):
        if not sel:
            return None
        if not is_desc:
            o = outputs.get(sel)
            return sel if (o and o["connected"] and sel not in used) else None
        seln = sel.lower()
        for name, info in outputs.items():
            if info["connected"] and name not in used and seln in info["edid"].lower():
                return name
        return None

    def set_output(panel, value):
        subprocess.run([XQ, "-c", "xfce4-panel",
                        "-p", "/panels/panel-%d/output-name" % panel,
                        "--create", "-t", "string", "-s", value])

    def main():
        panels = json.load(open(sys.argv[1]))
        outputs = get_outputs()
        used = set()
        for p in panels:
            conn = resolve(p["selector"], p["isDesc"], outputs, used) if p["selector"] else None
            if p["primary"]:
                # Full taskbar → the primary monitor's connector (resolved by EDID, so it
                # doesn't depend on --primary having been set yet); fall back to "Primary".
                if conn:
                    used.add(conn)
                set_output(p["panel"], conn or "Primary")
            elif conn:
                used.add(conn)
                set_output(p["panel"], conn)
            else:
                # Monitor absent → bind to a name that can't match so the panel stays hidden
                # (rather than piling a duplicate onto the primary).
                set_output(p["panel"], "__absent-panel-%d__" % p["panel"])
        subprocess.run([PANEL, "-r"])

    main()
  '';

  bindScript = pkgs.writeShellScript "win7-bind-panels" ''
    exec ${pkgs.python3}/bin/python3 ${bindPy} ${panelBindJson}
  '';

  # ---- Tray applets (primary panel systray) ----------------------------------------------
  trayCmd = {
    network = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
    bluetooth = "${pkgs.blueman}/bin/blueman-applet";
    power = "${pkgs.xfce.xfce4-power-manager}/bin/xfce4-power-manager --no-daemon";
    clipboard = "${pkgs.xfce.xfce4-clipman-plugin}/bin/xfce4-clipman";
    nightlight = "${pkgs.redshift}/bin/redshift-gtk";
  };

  # redshift needs a location; seed a manual one so redshift-gtk works without geoclue.
  # Temperatures + location come from the declarative xfcePanel.nightlight options.
  nl = panelCfg.nightlight;
  redshiftConf = lib.optionalAttrs (lib.elem "nightlight" trays) {
    "redshift/redshift.conf".text = ''
      [redshift]
      temp-day=${toString nl.tempDay}
      temp-night=${toString nl.tempNight}
      transition=1
      location-provider=manual
      adjustment-method=randr

      [manual]
      lat=${toString nl.latitude}
      lon=${toString nl.longitude}
    '';
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
      whiskerRcFiles
      trayFiles
      redshiftConf
      {
        "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml".text = panelXml;
        # Bind panels to their monitors by EDID after the session (and monitor layout) come up.
        "autostart/win7-bind-panels.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Windows 7 panel monitor binding
          Exec=${bindScript}
          OnlyShowIn=XFCE;
          X-XFCE-Autostart-enabled=true
        '';
      }
    ];
  };
}
