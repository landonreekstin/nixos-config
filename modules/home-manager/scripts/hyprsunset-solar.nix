# ~/nixos-config/modules/home-manager/scripts/hyprsunset-solar.nix
#
# hyprsunset-isday — the single source of truth for "is it daytime?".
#
# Not a module: a plain function returning the package, imported by both
# scripts/hyprsunset-control.nix (the schedule/init) and
# de-wm-components/waybar/functional.nix (the four click/scroll handlers), so
# that nothing can disagree about which side of the boundary we are on. The
# hour arithmetic used to be copy-pasted into five scripts.
#
# Prints 1 for day, 0 for night. Uses the real sun position at the configured
# coordinates; falls back to the fixed dayStartHour/nightStartHour window when
# solar tracking is off or sunwait errors out.
{ pkgs, cfg }:

pkgs.writeShellScriptBin "hyprsunset-isday" ''
  fixed_window() {
    HOUR=$(date +%-H)
    if [ "$HOUR" -ge ${toString cfg.dayStartHour} ] && [ "$HOUR" -lt ${toString cfg.nightStartHour} ]; then
      echo 1
    else
      echo 0
    fi
  }

  ${pkgs.lib.optionalString cfg.solar.enable ''
    # sunwait poll: exit 2 = day (or twilight), 3 = night, 1 = error.
    ${pkgs.sunwait}/bin/sunwait poll ${cfg.solar.twilight} \
      ${cfg.solar.latitude} ${cfg.solar.longitude} >/dev/null 2>&1
    case $? in
      2) echo 1; exit 0 ;;
      3) echo 0; exit 0 ;;
    esac
  ''}

  fixed_window
''
