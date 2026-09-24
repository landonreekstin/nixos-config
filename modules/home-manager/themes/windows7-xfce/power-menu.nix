# ~/nixos-config/modules/home-manager/themes/windows7-xfce/power-menu.nix
{ pkgs }:

# The Start-menu power flyout, factored out of panel.nix so keybindings.nix can bind the
# same window to <Super>BackSpace and the physical power key (a `let` binding cannot span
# files). panel.nix wires it to whiskermenu's command-logout with the panel's plugin id;
# the other callers invoke it with no argument, which is its standalone mode.
let
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

    class Guarded:
        # Wraps an action that must clear `shutdown-guard` before it runs
        # (modules/home-manager/services/shutdown-guard.nix). The guard is silent and instant
        # unless an automated update is due shortly, in which case it asks the user what to do
        # and a non-zero status means "don't". Only Shut Down is wrapped: a restart or log off
        # leaves the machine powered on, so the update still happens.
        def __init__(self, fn):
            self.fn = fn

        def __call__(self):
            return self.fn()

    def guard_ok():
        # Fail OPEN on any error (guard not installed on this host, crash, no display) — a
        # broken guard must never leave a machine that refuses to shut down.
        try:
            return subprocess.run(["shutdown-guard"], check=False).returncode == 0
        except Exception as exc:
            sys.stderr.write("win7-power-menu: " + str(exc) + "\n")
            return True

    # Power actions call the xfce4-session manager's D-Bus methods directly (allow_save=False
    # mirrors the old `--fast`; Logout show_dialog=False skips the fading confirm dialog). The
    # CLI equivalents need logind/polkit and silently no-op in the local `ly` session, so the
    # manager methods are the reliable path. All four go through mgr_retry for the
    # first-request-drop workaround above; Lock stays on xflock4 (no manager round-trip).
    ACTIONS = [
        ("Shut Down", "system-shutdown",    Guarded(lambda: mgr_retry("Shutdown", GLib.Variant("(b)", (False,))))),
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
            if isinstance(action, Guarded) and not guard_ok():
                # An automated update is imminent and the user chose not to shut down after
                # all. Dismiss the Start menu behind us and quit; restore() runs in main()'s
                # finally, so nothing else needs undoing here.
                self._close_start = True
                Gtk.main_quit()
                return
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
in
powerMenu
