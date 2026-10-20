# ~/nixos-config/modules/home-manager/services/shutdown-guard.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.shutdownGuard;
  auto = customConfig.services.autoUpdate;

  # The unit whose schedule the guard reads (modules/nixos/common/auto-update.nix).
  timerUnit = "nixos-auto-update.timer";

  # Where blaney-todo reads its runbooks from (modules/nixos/common/commands.nix), and the
  # file blaney-todo-unattended records finished ones in, so they are not offered twice.
  repoDir = "${customConfig.user.home}/nixos-config";
  runbookDir = "docs/runbooks/blaney";

  # Terminal the "Update now" button runs `update-shutdown` in, so the user can watch the
  # rebuild and answer its sudo prompt. Falls back to kitty on hosts with no terminal role.
  terminalCmd =
    let c = customConfig.apps.programs.terminal.command or "";
    in if c != "" then c else "${pkgs.kitty}/bin/kitty";

  # GTK3 + PyGObject, packaged like the windows7-xfce power flyout
  # (modules/home-manager/themes/windows7-xfce/power-menu.nix). GTK3 specifically: it inherits
  # whatever GTK theme the session sets (the Win7 theme on blaney-pc) and gets a real xfwm4
  # titlebar, where zenity 4.x is GTK4/libadwaita and would render as stock Adwaita.
  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  # Called with two arguments: when the update is due ("" if it isn't due soon) and how many
  # of Lando's tasks are waiting ("0" if none). The wrapper only calls it if one applies.
  # Exit status contract, shared with the wrapper below:
  #   0  -> go ahead with the shutdown
  #   10 -> do not shut down (cancelled, or "Update now" / "Have Claude do a task" was
  #         launched and will power off itself)
  # Anything else means the dialog itself broke, and the wrapper fails OPEN (allows the
  # shutdown) so a GUI bug can never leave a machine that refuses to turn off.
  dialogPy = pkgs.writeText "shutdown-guard.py" ''
    import sys, subprocess
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk

    PROCEED, HOLD = 0, 10

    TERMINAL = "${terminalCmd}"
    WHEN = sys.argv[1] if len(sys.argv) > 1 else "soon"
    try:
        TASKS = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    except ValueError:
        TASKS = 0

    paras = []
    if WHEN:
        HEADING = "Are you sure you want to shut down?"
        paras.append(
            "This PC is scheduled to update itself around %s"
            "${lib.optionalString auto.shutdownAfterRebuild " and will shut itself off when it is done"}"
            ".\n\nIt needs to be left powered on for that to happen. "
            "You do not need to be logged in." % WHEN
        )
    else:
        HEADING = "Before you shut down\u2026"
    if TASKS:
        paras.append(
            "Lando left you %d task%s. Claude can do %s by itself while you are away, "
            "then update the PC and shut it off."
            % (TASKS, "" if TASKS == 1 else "s", "it" if TASKS == 1 else "one")
        )
    BODY = "\n\n".join(paras)

    RESP_CANCEL, RESP_SHUTDOWN, RESP_UPDATE, RESP_TASK = 1, 2, 3, 4

    def main():
        dlg = Gtk.MessageDialog(
            transient_for=None, modal=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.NONE,
            text=HEADING,
        )
        dlg.format_secondary_text(BODY)
        dlg.set_title("Shut down")
        dlg.set_icon_name("system-shutdown")
        dlg.set_keep_above(True)
        dlg.set_position(Gtk.WindowPosition.CENTER)
        dlg.add_button("Cancel", RESP_CANCEL)
        dlg.add_button("Shut down anyway", RESP_SHUTDOWN)
        if WHEN:
            dlg.add_button("Update now, then shut down", RESP_UPDATE)
        if TASKS:
            dlg.add_button("Have Claude do a task, then shut down", RESP_TASK)
        dlg.set_default_response(RESP_CANCEL)

        dlg.present()
        resp = dlg.run()
        dlg.destroy()
        # Let the window actually disappear before we hand control back to the caller.
        while Gtk.events_pending():
            Gtk.main_iteration()

        if resp == RESP_SHUTDOWN:
            return PROCEED
        if resp == RESP_UPDATE:
            # start_new_session so the terminal outlives this process, and so quitting the
            # guard never signals the update's process group mid-rebuild.
            subprocess.Popen(TERMINAL + " -e update-shutdown",
                             shell=True, start_new_session=True)
        if resp == RESP_TASK:
            # blaney-todo still asks which task (and for the password) before he walks away;
            # --unattended skips its "with me or on its own?" question.
            subprocess.Popen(TERMINAL + " -e blaney-todo --unattended",
                             shell=True, start_new_session=True)
        # Cancel, window closed, or Escape -> hold.
        return HOLD

    try:
        sys.exit(main())
    except Exception as exc:
        sys.stderr.write("shutdown-guard: " + str(exc) + "\n")
        sys.exit(PROCEED)
  '';

  dialog = pkgs.stdenv.mkDerivation {
    name = "shutdown-guard-dialog";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pyEnv ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      { echo '#!${pyEnv}/bin/python3'; cat ${dialogPy}; } > $out/bin/shutdown-guard-dialog
      chmod +x $out/bin/shutdown-guard-dialog
      runHook postInstall
    '';
  };

  # Callers reduce to `shutdown-guard || exit`: status 0 means go ahead, 1 means don't.
  # Silent and instant whenever no automated update is due inside the warning window, so it
  # is safe to put in front of every shutdown path.
  guard = pkgs.writeShellApplication {
    name = "shutdown-guard";
    runtimeInputs = [ pkgs.systemd pkgs.coreutils pkgs.git pkgs.gnugrep ];
    text = ''
      # NextElapseUSecRealtime already folds in the timer's RandomizedDelaySec, so the time
      # it reports is the real expected wake-up (hence "around" in the dialog wording).
      # --timestamp=unix is required: plain --value pretty-prints the timestamp ("Mon
      # 2026-09-28 03:12:04 CDT") rather than a number. It yields "@<seconds>", seconds
      # despite the property's USec name.
      # --- Is the weekly update due inside the warning window? -> $when ("" if not) ---------
      when=""
      raw=$(systemctl show --timestamp=unix --property=NextElapseUSecRealtime --value ${timerUnit} 2>/dev/null || true)
      due=''${raw#@}

      # Unit absent, never scheduled, or not a realtime timer -> nothing to warn about.
      case "$due" in
        "" | *[!0-9]* ) due=0 ;;
      esac
      now=$(date +%s)
      if [ "$due" -gt "$now" ] && [ "$(( due - now ))" -le $(( ${toString cfg.warnWithinHours} * 3600 )) ]; then
        when=$(date -d "@$due" '+%A at %-I:%M %p')
      fi

      # --- How many of Lando's runbooks are waiting? -> $tasks ---------------------------
      # Read from the last-fetched origin/main with no network access, so the guard stays
      # instant offline; blaney-todo fetches fresh when it actually runs. Runbooks a
      # walk-away run already finished are not counted. Any git error counts as none.
      tasks=0
      ${lib.optionalString cfg.offerTasks ''
        # An empty pattern list (no done file yet) filters nothing out. Under pipefail a grep
        # that filters every line exits 1, which lands on the `|| tasks=0` — also correct.
        tasks=$(git -C ${repoDir} ls-tree --name-only origin/main ${runbookDir}/ 2>/dev/null \
          | grep '\.md$' | grep -v '/README\.md$' \
          | grep -cvxF -f <(cat "$HOME/.local/state/blaney-todo-done" 2>/dev/null || true)) || tasks=0
        case "$tasks" in "" | *[!0-9]* ) tasks=0 ;; esac
      ''}

      if [ -z "$when" ] && [ "$tasks" -eq 0 ]; then
        exit 0
      fi

      # Fail open: only an explicit "hold" status blocks the shutdown, so a broken or
      # unreachable dialog can never leave the machine unable to power off.
      rc=0
      ${dialog}/bin/shutdown-guard-dialog "$when" "$tasks" || rc=$?
      if [ "$rc" -eq 10 ]; then
        exit 1
      fi
      exit 0
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && auto.enable) {
    home.packages = [ guard ];
  };
}
