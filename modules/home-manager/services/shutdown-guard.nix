# ~/nixos-config/modules/home-manager/services/shutdown-guard.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.shutdownGuard;

  # The config checkout `update` pulls (modules/nixos/common/commands.nix) — the guard asks
  # whether origin/main has commits it doesn't — and where blaney-todo reads its runbooks.
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

  # Called with two arguments: how many new commits origin/main has that this checkout
  # doesn't, and how many of Lando's tasks are waiting. The wrapper only calls it when at
  # least one is non-zero.
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

    def count(i):
        try:
            return int(sys.argv[i]) if len(sys.argv) > i else 0
        except ValueError:
            return 0

    UPDATES, TASKS = count(1), count(2)

    HEADING = "Before you shut down\u2026"
    paras = []
    if UPDATES:
        paras.append(
            "Lando has sent new updates for this PC that are not installed yet. "
            "It can install them now and shut itself off when it is done."
        )
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
        if UPDATES:
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
  # Silent whenever there is nothing new to install and no task waiting, so it is safe to
  # put in front of every shutdown path.
  guard = pkgs.writeShellApplication {
    name = "shutdown-guard";
    runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.gnugrep pkgs.openssh ];
    text = ''
      # --- Does origin/main have commits this checkout doesn't? -> $updates -------------
      # A short, bounded fetch first so the answer is current; offline or slow, it gives up
      # within 4 seconds (the Start menu waits on this) and the last-fetched origin/main is used instead. BatchMode and
      # GIT_TERMINAL_PROMPT=0 so a credential problem fails rather than waiting on input.
      GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=3" \
        timeout 4 git -C ${repoDir} fetch --quiet origin main >/dev/null 2>&1 || true
      updates=$(git -C ${repoDir} rev-list --count HEAD..origin/main 2>/dev/null) || updates=0
      case "$updates" in "" | *[!0-9]* ) updates=0 ;; esac

      # --- How many of Lando's runbooks are waiting? -> $tasks ---------------------------
      # Read from the origin/main just fetched above. Runbooks a walk-away run already
      # finished are not counted. Any git error counts as none.
      tasks=0
      ${lib.optionalString cfg.offerTasks ''
        # An empty pattern list (no done file yet) filters nothing out. Under pipefail a grep
        # that filters every line exits 1, which lands on the `|| tasks=0` — also correct.
        tasks=$(git -C ${repoDir} ls-tree --name-only origin/main ${runbookDir}/ 2>/dev/null \
          | grep '\.md$' | grep -v '/README\.md$' \
          | grep -cvxF -f <(cat "$HOME/.local/state/blaney-todo-done" 2>/dev/null || true)) || tasks=0
        case "$tasks" in "" | *[!0-9]* ) tasks=0 ;; esac
      ''}

      if [ "$updates" -eq 0 ] && [ "$tasks" -eq 0 ]; then
        exit 0
      fi

      # Fail open: only an explicit "hold" status blocks the shutdown, so a broken or
      # unreachable dialog can never leave the machine unable to power off.
      rc=0
      ${dialog}/bin/shutdown-guard-dialog "$updates" "$tasks" || rc=$?
      if [ "$rc" -eq 10 ]; then
        exit 1
      fi
      exit 0
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ guard ];
  };
}
