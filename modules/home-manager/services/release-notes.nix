# ~/nixos-config/modules/home-manager/services/release-notes.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.releaseNotes;

  # Both lists are baked in at build time, so a note (or a new task) only pops up once the
  # commit that adds it has actually been built on this machine — i.e. after an update.
  entriesJson = pkgs.writeText "release-notes.json" (builtins.toJSON cfg.entries);

  # Same folder and the same title rule as `blaney-todo` (modules/nixos/common/blaney-commands.nix):
  # every .md except README.md, titled by its first `# ` heading minus any "Runbook: ".
  runbookDir = ../../../docs/runbooks/blaney;
  runbookTitle = file:
    let
      heading = lib.findFirst (l: lib.hasPrefix "# " l) null
        (lib.splitString "\n" (builtins.readFile (runbookDir + "/${file}")));
      stripped = if heading == null then "" else
        lib.removePrefix "runbook: " (lib.removePrefix "Runbook: "
          (lib.removePrefix "# " heading));
    in if stripped == "" then lib.removeSuffix ".md" file else stripped;
  runbooks =
    if cfg.showNewTasks && builtins.pathExists runbookDir then
      map (file: { inherit file; title = runbookTitle file; })
        (lib.sort lib.lessThan (lib.filter
          (f: lib.hasSuffix ".md" f && f != "README.md")
          (lib.attrNames (lib.filterAttrs (_: t: t == "regular")
            (builtins.readDir runbookDir)))))
    else [ ];
  runbooksJson = pkgs.writeText "release-notes-runbooks.json" (builtins.toJSON runbooks);

  # GTK3 + PyGObject, packaged like the shutdown guard (shutdown-guard.nix), so it picks up
  # the session's GTK theme (Win7 on blaney-pc) and gets a real titlebar.
  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  # Seen state: {"entries": [<sha256 of each note shown>], "runbooks": [<file names>]}.
  # Hashing a note's text means one added later on the same date still shows, and an old one
  # that is reworded does not come back. On the very first run every runbook that already
  # exists is recorded as seen without a popup, so only tasks added from then on are "new".
  # `--all` (the `whats-new` command) shows every note and every waiting task regardless.
  dialogPy = pkgs.writeText "release-notes.py" ''
    import sys, os, json, hashlib, html
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import GLib, Gtk, Pango

    # Otherwise the window class is ".release-notes-dialog-wrapped" and bars guess a name.
    GLib.set_prgname("release-notes")
    GLib.set_application_name("Release notes")

    TITLE = ${builtins.toJSON cfg.title}
    ENTRIES = json.load(open("${entriesJson}"))
    RUNBOOKS = json.load(open("${runbooksJson}"))
    STATE = os.path.expanduser("~/.local/state/release-notes-seen.json")
    SHOW_ALL = "--all" in sys.argv

    def entry_id(e):
        text = e.get("date", "") + "\n" + "\n".join(e.get("changes", []))
        return hashlib.sha256(text.encode()).hexdigest()

    def load_state():
        try:
            with open(STATE) as f:
                s = json.load(f)
            return set(s.get("entries", [])), set(s.get("runbooks", []))
        except (OSError, ValueError):
            return None

    def save_state(entries, runbooks):
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        tmp = STATE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"entries": sorted(entries), "runbooks": sorted(runbooks)}, f)
        os.replace(tmp, STATE)

    def markup(entries, tasks):
        out = []
        if entries:
            out.append("<b>What's new</b>")
            for e in entries:
                out.append("")
                out.append("<i>%s</i>" % html.escape(e.get("date", "")))
                for c in e.get("changes", []):
                    out.append("•  " + html.escape(c))
        if tasks:
            if out:
                out.append("")
            out.append("<b>%s</b>" % ("Tasks from Lando" if SHOW_ALL else "New tasks from Lando"))
            out.append("")
            for r in tasks:
                out.append("•  " + html.escape(r["title"]))
            out.append("")
            out.append("Type <b>blaney-todo</b> in a terminal to have Claude do one.")
        if not out:
            out.append("Nothing new right now.")
        return "\n".join(out)

    def show(text):
        dlg = Gtk.Dialog(title=TITLE, modal=True)
        dlg.set_icon_name("dialog-information")
        dlg.set_keep_above(True)
        dlg.set_position(Gtk.WindowPosition.CENTER)
        dlg.set_default_size(480, -1)
        box = dlg.get_content_area()
        box.set_spacing(12)
        box.set_border_width(16)

        heading = Gtk.Label(xalign=0)
        heading.set_markup("<span size='large' weight='bold'>%s</span>" % html.escape(TITLE))
        box.pack_start(heading, False, False, 0)

        body = Gtk.Label(xalign=0, yalign=0)
        body.set_markup(text)
        body.set_line_wrap(True)
        body.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        body.set_max_width_chars(60)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_propagate_natural_height(True)
        scroll.set_max_content_height(420)
        scroll.add(body)
        box.pack_start(scroll, True, True, 0)

        dlg.add_button("Got it", Gtk.ResponseType.OK)
        dlg.set_default_response(Gtk.ResponseType.OK)
        dlg.show_all()
        dlg.present()
        dlg.run()
        dlg.destroy()

    def main():
        all_ids = {entry_id(e) for e in ENTRIES}
        all_files = {r["file"] for r in RUNBOOKS}
        state = load_state()
        if state is None:
            seen_entries, seen_files = set(), set(all_files)
            save_state(seen_entries, seen_files)
        else:
            seen_entries, seen_files = state

        if SHOW_ALL:
            entries, tasks = ENTRIES, RUNBOOKS
        else:
            entries = [e for e in ENTRIES if entry_id(e) not in seen_entries]
            tasks = [r for r in RUNBOOKS if r["file"] not in seen_files]
            if not entries and not tasks:
                return 0

        show(markup(entries, tasks))
        # Keep seen runbooks that were since deleted out of the file: they are gone for good.
        save_state(seen_entries | all_ids, (seen_files | all_files) & all_files)
        return 0

    try:
        sys.exit(main())
    except Exception as exc:
        sys.stderr.write("release-notes: " + str(exc) + "\n")
        sys.exit(0)
  '';

  dialog = pkgs.stdenv.mkDerivation {
    name = "release-notes-dialog";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pyEnv ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      { echo '#!${pyEnv}/bin/python3'; cat ${dialogPy}; } > $out/bin/release-notes-dialog
      chmod +x $out/bin/release-notes-dialog
      runHook postInstall
    '';
  };

  # Run from a login timer, so the session may not have handed its display to the systemd
  # user manager yet. The service's own environment is fixed when it starts, so poll the
  # manager's (`show-environment`) for up to a minute and take the display vars from there.
  loginCheck = pkgs.writeShellScript "release-notes-login" ''
    for _ in $(seq 30); do
      env=$(${pkgs.systemd}/bin/systemctl --user show-environment 2>/dev/null)
      if printf '%s\n' "$env" | ${pkgs.gnugrep}/bin/grep -qE '^(DISPLAY|WAYLAND_DISPLAY)='; then
        while IFS= read -r line; do
          case "$line" in
            DISPLAY=*|WAYLAND_DISPLAY=*|XAUTHORITY=*|XDG_RUNTIME_DIR=*|DBUS_SESSION_BUS_ADDRESS=*)
              export "$line" ;;
          esac
        done <<< "$env"
        exec ${dialog}/bin/release-notes-dialog
      fi
      sleep 2
    done
    exit 0
  '';

  whatsNew = pkgs.writeShellScriptBin "whats-new" ''
    # The Win7 GTK theme spams parse warnings into the terminal he ran this from.
    exec ${dialog}/bin/release-notes-dialog --all 2>/dev/null
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ whatsNew ];

    # Named after the window's app id (GLib.set_prgname above), so taskbars label the popup
    # "What's new" instead of guessing; doubles as a menu entry that reopens the notes.
    xdg.desktopEntries.release-notes = {
      name = "What's new";
      comment = "Lando's notes about what changed on this PC";
      exec = "${whatsNew}/bin/whats-new";
      icon = "dialog-information";
      categories = [ "Utility" ];
      settings.StartupWMClass = "release-notes";
    };

    systemd.user.services.release-notes = {
      Unit.Description = "Show Lando's release notes after an update";
      Service = {
        Type = "oneshot";
        ExecStart = "${loginCheck}";
      };
    };

    systemd.user.timers.release-notes = {
      Unit.Description = "Show new release notes shortly after login";
      Timer = {
        OnStartupSec = "45s";
        Unit = "release-notes.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
