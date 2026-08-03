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
  xfconfBin = "${pkgs.xfce.xfconf}/bin";                      # xfconf-query
  whiskerBin = "${pkgs.xfce.xfce4-whiskermenu-plugin}/bin";   # xfce4-popup-whiskermenu
  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  powerMenuPy = pkgs.writeText "win7-power-menu.py" ''
    import gi, subprocess, sys, signal, time
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib, Gio

    LOCK = "${sessionBin}/xflock4"
    XFCONF = "${xfconfBin}/xfconf-query"
    POPUP = "${whiskerBin}/xfce4-popup-whiskermenu"

    # Optional whiskermenu instance id: the Start menu passes its own plugin id when it opens
    # this flyout, so we can keep that Start menu visible underneath (Win7 behavior — the
    # menu otherwise hides itself the instant its power button is clicked). Absent when the
    # flyout is invoked standalone -> it behaves as a plain power menu (no reopen/toggle).
    WID = sys.argv[1] if len(sys.argv) > 1 else None
    STAY_PROP = "/plugins/plugin-%s/stay-on-focus-out" % WID if WID else None

    BUS = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def mgr(method, params):
        BUS.call_sync("org.xfce.SessionManager", "/org/xfce/SessionManager",
                      "org.xfce.Session.Manager", method, params,
                      None, Gio.DBusCallFlags.NONE, -1, None)

    def run(argv):
        try:
            subprocess.run(argv, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            sys.stderr.write("win7-power-menu: " + str(exc) + "\n")

    def set_stay(value):
        # Toggle whiskermenu "stay visible when focus is lost" live via xfconf so the reopened
        # Start menu does not hide when this flyout takes focus. -n creates the key if absent;
        # whiskermenu watches the xfce4-panel channel and applies it immediately.
        if STAY_PROP:
            run([XFCONF, "-c", "xfce4-panel", "-p", STAY_PROP,
                 "-n", "-t", "bool", "-s", "true" if value else "false"])

    def toggle_start():
        # xfce4-popup-whiskermenu -i N targets exactly this panel's Start menu (shows it if
        # hidden, hides it if visible) — so on multi-panel hosts only the clicked monitor's
        # Start is affected, not every panel.
        if WID:
            run([POPUP, "-i", WID])

    _restored = [False]
    def restore():
        # Revert stay-on-focus-out so the Start menu returns to normal dismiss behavior.
        # Idempotent: runs at most once across all exit paths (finally + signals).
        if not _restored[0]:
            _restored[0] = True
            set_stay(False)

    def mgr_retry(method, params):
        # xfce4-session under `ly` silently DROPS the FIRST session-manager request per session
        # (the call returns rc=0 but nothing happens — an ICE/first-connection race); the next
        # one is honored. This hits Shut Down / Restart / Suspend / Log Off equally (Lock is
        # unaffected — it's xflock4, not a manager round-trip), and it's not the flyout's click
        # handling (Lock, same code path, always fires first-click). Work around it by issuing
        # the request, then re-issuing once ~0.6s later.
        #   - Shut Down / Restart / Log Off: if the first was honored, teardown SIGTERMs this
        #     process (see on_signal) before the retry fires, so there is no double action.
        #   - Suspend: teardown does NOT happen, so guard the retry on WALL time (time.time(),
        #     which counts time spent suspended) — if the machine actually suspended and resumed,
        #     far more than a few seconds have passed, so skip the retry instead of re-suspending.
        def send():
            try:
                mgr(method, params)
            except Exception as exc:
                sys.stderr.write("win7-power-menu: " + str(exc) + "\n")
        t0 = time.time()
        send()
        def retry():
            if time.time() - t0 < 3.0:
                send()          # first request was dropped (no suspend/teardown) -> honor it now
            Gtk.main_quit()
            return False
        GLib.timeout_add(600, retry)
        return True             # keep the main loop alive for the retry

    # Power actions call the xfce4-session manager's D-Bus methods directly (allow_save=False
    # mirrors the old `--fast`; Logout show_dialog=False skips the fading confirm dialog). The
    # CLI equivalents need logind/polkit and silently no-op in the local `ly` session, so the
    # manager methods are the reliable path. All four go through mgr_retry for the
    # first-request-drop workaround above; Lock stays on xflock4 (no manager round-trip).
    ACTIONS = [
        ("Shut Down", "system-shutdown",    lambda: mgr_retry("Shutdown", GLib.Variant("(b)", (False,)))),
        ("Restart",   "system-reboot",      lambda: mgr_retry("Restart",  GLib.Variant("(b)", (False,)))),
        ("Sleep",     "system-suspend",     lambda: mgr_retry("Suspend",  None)),
        ("Log Off",   "system-log-out",     lambda: mgr_retry("Logout",   GLib.Variant("(bb)", (False, False)))),
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
                btn.connect("button-press-event", self.on_button_press, action)
                btn.connect("clicked", self.on_click, action)
                box.pack_start(btn, False, False, 0)

            self._ready = False
            self._close_start = False
            self._acting = False        # set once an action/dismiss is committed
            self._reraise_ids = []      # pending proactive-raise timeout source ids
            self.connect("key-press-event", self.on_key)
            self.connect("focus-out-event", self.on_focus_out)
            self.connect("destroy", Gtk.main_quit)

        def freeze(self):
            # Commit to closing: stop the proactive raises and make the focus handlers inert so
            # nothing re-raises or re-shows the flyout while an action fires / it tears down.
            # (A stray raise coinciding with the click is what made Log Off need two tries.)
            self._acting = True
            for sid in self._reraise_ids:
                GLib.source_remove(sid)
            self._reraise_ids = []

        def arm_dismiss(self):
            # Start the focus-out guard from when the window is actually shown (not built), so
            # the spurious focus-out during the initial map is ignored while a real click-away
            # later closes it. Called by main() after show_all().
            GLib.timeout_add(300, self._enable_dismiss)

        def _enable_dismiss(self):
            self._ready = True
            return False

        def _pointer_inside(self):
            # True if the mouse is currently over the flyout's rectangle (root coords).
            try:
                seat = Gdk.Display.get_default().get_default_seat()
                _s, px, py = seat.get_pointer().get_position()
                gx, gy = self.get_position()
                a = self.get_allocation()
                m = 4  # small slop
                return (gx - m) <= px <= (gx + a.width + m) \
                   and (gy - m) <= py <= (gy + a.height + m)
            except Exception:
                return False

        def raise_self(self):
            # Pop the flyout back on top and re-take focus.
            self.present()
            w = self.get_window()
            if w is not None:
                w.raise_()

        def on_focus_out(self, *args):
            # We lost focus. Two very different causes, told apart by the pointer:
            #  - The Start menu finished its (async, sometimes slow) reopen and grabbed focus on
            #    top of us — the pointer is still over the flyout (user just clicked the power
            #    button here). Reclaim top+focus, do NOT close — and do this REGARDLESS of the
            #    dismiss guard, because in a fast session Start steals focus within the first
            #    300ms and we must still come back on top.
            #  - The user clicked the desktop / another window — pointer is elsewhere. Dismiss
            #    the flyout AND the Start menu, Win7-style (only once the guard has opened, to
            #    ignore the brief focus churn during our own initial map).
            if self._acting:
                return False
            if self._pointer_inside():
                self.raise_self()
            elif self._ready:
                self._close_start = True
                Gtk.main_quit()
            return False

        def on_key(self, widget, event):
            if event.keyval == Gdk.KEY_Escape:
                # Esc dismisses both, same as a click-away. (Leaving Start open here stranded it:
                # once the flyout closed, Start didn't reliably re-take focus, so a later
                # desktop-click never produced the focus-out that would dismiss it.)
                self._close_start = True
                self.freeze()
                Gtk.main_quit()
            return False

        def _activate(self, action):
            # Run one flyout action exactly once. Guarded by _acting so the mouse path
            # (button-press-event) and the keyboard path ("clicked") never double-fire.
            if self._acting:
                return
            # Freeze first so no proactive raise / focus-out reshow steals this activation, then
            # hide and run the action. No event pump here — pumping processed the hide's own
            # focus-out, which re-showed the flyout.
            self.freeze()
            self.hide()
            keep_alive = False
            try:
                keep_alive = bool(action())
            except Exception as exc:
                sys.stderr.write("win7-power-menu: " + str(exc) + "\n")
            # Most actions return None -> quit now. Log Off returns True to keep the main loop
            # alive briefly for its retry (see logout()); the session teardown or the retry's own
            # main_quit ends the loop.
            if not keep_alive:
                Gtk.main_quit()

        def on_button_press(self, button, event, action):
            # Commit on the PRESS, not the full press+release "clicked". On multi-monitor X11 a
            # proactive raise (win._reraise_ids) firing between the press and release cancels the
            # button's implicit grab, so "clicked" is never emitted and the first click is lost
            # (the two-click bug — llvmpipe in a VM is slow enough to never land a raise mid-click).
            # Acting on the press and freezing here (which stops the reraises) makes the first
            # click always register. Returning True keeps the button out of its pressed state so
            # "clicked" does not also fire for the mouse path.
            self._activate(action)
            return True

        def on_click(self, button, action):
            # Keyboard activation (Space/Enter on a focused button) emits "clicked" with no
            # button-press-event; keep this path. _acting guards against the mouse path.
            self._activate(action)

    def main():
        win = PowerMenu()

        def on_signal(*_):
            Gtk.main_quit()
            return GLib.SOURCE_REMOVE
        for sig in (signal.SIGINT, signal.SIGTERM):
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, on_signal)

        if WID:
            # Keep the clicked panel's Start menu open under the flyout: let it survive the
            # focus steal (stay-on-focus-out), then reopen it (whiskermenu hid it running this
            # command; its anti-toggle timer was reset, so this shows rather than re-hides).
            set_stay(True)
            toggle_start()

        # Show the flyout immediately. The Start menu reopens asynchronously and, being
        # keep-above, tends to map on top of us a moment later. on_focus_out reclaims the top
        # spot reactively, but also raise proactively a few times over the first ~0.6s (only
        # while the pointer is still on the flyout, i.e. the user hasn't moved to click away) so
        # we win the stacking race whenever Start finally maps, without guessing its delay.
        win.show_all()
        win.present()
        win.arm_dismiss()

        if WID:
            def reraise():
                if not win._acting and win.get_visible() and win._pointer_inside():
                    win.raise_self()
                return False
            for delay in (80, 200, 380, 600):
                win._reraise_ids.append(GLib.timeout_add(delay, reraise))

        try:
            Gtk.main()
        finally:
            restore()
            if win._close_start:
                toggle_start()  # Start is still visible here -> this hides it.

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
  # Parameterised by the panel's whiskermenu instance id so command-logout can hand it to the
  # power flyout, which uses it to keep this same Start menu open underneath (see powerMenuPy).
  whiskerRcFor = id: ''
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
    command-logout=${powerMenu}/bin/win7-power-menu ${toString id}
    show-command-logout=true
    search-actions=5
  '';
  # whiskermenu (Start menu) rc — seeded per panel as a WRITABLE copy via home.activation
  # (below), NOT a read-only xdg.configFile symlink. whiskermenu rewrites its own rc at runtime
  # (favorites / recently-used), and writing through a store symlink clobbers it — which is why
  # the *active* panels' whiskermenu-N.rc used to vanish after login, leaving the Start menu
  # with no command-logout so it fell back to the stock xfce4-session-logout two-click dialog.
  whiskerRcStoreFor = id: pkgs.writeText "win7-whiskermenu-${toString id}.rc" (whiskerRcFor id);

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
  # Clipman self-registers an autostart entry named xfce4-clipman-plugin-autostart.desktop
  # (Hidden=false) the first time it runs. If we launch it under a *different* filename, that
  # self-written entry becomes a SECOND launcher → clipman's "already running" popup on every
  # login. So emit the clipboard tray under clipman's own canonical filename: there is then
  # only ever one entry (our read-only HM symlink), and any runtime self-write lands on the
  # same path instead of creating a competing one. dropStaleClipmanAutostart (below) clears a
  # pre-existing real file so HM can own the path.
  trayFileName = t:
    if t == "clipboard"
    then "autostart/xfce4-clipman-plugin-autostart.desktop"
    else "autostart/win7-tray-${t}.desktop";
  trayFiles = lib.listToAttrs (map (t: {
    name = trayFileName t;
    value.text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 tray: ${t}
      Exec=${trayCmd.${t}}
      OnlyShowIn=XFCE;
      Hidden=false
      X-XFCE-Autostart-enabled=true
    '';
  }) trays);
in {
  config = lib.mkIf win7XfceCondition {
    xdg.configFile = lib.mkMerge [
      launcherFiles
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

    # Seed each panel's whiskermenu rc as a WRITABLE copy after HM links the generation, rather
    # than as a read-only xdg.configFile symlink that whiskermenu clobbers when it rewrites its
    # own state (see whiskerRcStoreFor above). Seed only when the file is absent so the two
    # xfceOverride modes both behave: ON wipes ~/.config/xfce4/panel each rebuild (entryBefore
    # linkGeneration), so the file is absent here and gets re-asserted with the current theme
    # content; OFF leaves the file in place, preserving the user's runtime favorites/recents.
    # Clipman writes ~/.config/autostart/xfce4-clipman-plugin-autostart.desktop (Hidden=false)
    # as a real file, which HM won't clobber when it links our canonical clipboard autostart
    # (trayFileName "clipboard"). Remove that real file before linkGeneration — but only when
    # it's a non-symlink, so we never delete HM's own link. Idempotent across rebuilds.
    home.activation.dropStaleClipmanAutostart =
      lib.mkIf (lib.elem "clipboard" trays)
        (lib.hm.dag.entryBefore [ "linkGeneration" ] ''
          _clipman_autostart="${config.xdg.configHome}/autostart/xfce4-clipman-plugin-autostart.desktop"
          if [ -e "$_clipman_autostart" ] && [ ! -L "$_clipman_autostart" ]; then
            run rm -f "$_clipman_autostart"
          fi
        '');

    home.activation.seedWin7WhiskerRc = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatMapStringsSep "\n" (e:
        let
          id = panelBase e.i + 1;
          target = "${config.xdg.configHome}/xfce4/panel/whiskermenu-${toString id}.rc";
        in ''
          if [ ! -e "${target}" ]; then
            run ${pkgs.coreutils}/bin/install -Dm644 ${whiskerRcStoreFor id} "${target}"
          fi
        ''
      ) indexedMons
    );
  };
}
