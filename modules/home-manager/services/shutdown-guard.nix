# ~/nixos-config/modules/home-manager/services/shutdown-guard.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.shutdownGuard;
  auto = customConfig.services.autoUpdate;

  # The unit whose schedule the guard reads (modules/nixos/common/auto-update.nix).
  timerUnit = "nixos-auto-update.timer";

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

  # Exit status contract, shared with the wrapper below:
  #   0  -> go ahead with the shutdown
  #   10 -> do not shut down (cancelled, or "Update now" was launched and will power off itself)
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

    HEADING = "Are you sure you want to shut down?"
    BODY = (
        "This PC is scheduled to update itself around %s"
        "${lib.optionalString auto.shutdownAfterRebuild " and will shut itself off when it is done"}"
        ".\n\nIt needs to be left powered on for that to happen. "
        "You do not need to be logged in." % WHEN
    )

    RESP_CANCEL, RESP_SHUTDOWN, RESP_UPDATE = 1, 2, 3

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
        dlg.add_button("Update now, then shut down", RESP_UPDATE)
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
    runtimeInputs = [ pkgs.systemd pkgs.coreutils ];
    text = ''
      # NextElapseUSecRealtime already folds in the timer's RandomizedDelaySec, so the time
      # it reports is the real expected wake-up (hence "around" in the dialog wording).
      # --timestamp=unix is required: plain --value pretty-prints the timestamp ("Mon
      # 2026-09-28 03:12:04 CDT") rather than a number. It yields "@<seconds>", seconds
      # despite the property's USec name.
      raw=$(systemctl show --timestamp=unix --property=NextElapseUSecRealtime --value ${timerUnit} 2>/dev/null || true)
      due=''${raw#@}

      # Unit absent, never scheduled, or not a realtime timer -> nothing to warn about.
      case "$due" in
        "" | *[!0-9]* ) exit 0 ;;
      esac
      if [ "$due" -eq 0 ]; then
        exit 0
      fi

      now=$(date +%s)
      if [ "$due" -le "$now" ] || [ "$(( due - now ))" -gt $(( ${toString cfg.warnWithinHours} * 3600 )) ]; then
        exit 0
      fi

      when=$(date -d "@$due" '+%A at %-I:%M %p')

      # Fail open: only an explicit "hold" status blocks the shutdown, so a broken or
      # unreachable dialog can never leave the machine unable to power off.
      rc=0
      ${dialog}/bin/shutdown-guard-dialog "$when" || rc=$?
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
