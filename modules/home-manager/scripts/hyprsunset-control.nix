# ~/nixos-config/modules/home-manager/scripts/hyprsunset-control.nix
#
# hyprsunset-init: starts the hyprsunset daemon at the correct temperature on login (exec-once).
# hyprsunset-schedule: performs a GRADUAL transition to the time-of-day target.
#   Only called by the systemd timer at dayStartHour and nightStartHour.
#   All user interactions (waybar scroll/click) are instant — see waybar/functional.nix.
#
# The daemon stays running at all times — temperature is updated via `hyprctl hyprsunset
# temperature <K>` which talks to the daemon without disconnecting wlr-gamma-control,
# so there is no CTM flash on transitions.
#
# State file: ~/.cache/hyprsunset-state  format: "NIGHT_TEMP:MODE"
#   MODE: auto | manual | disabled
# Active temp: ~/.cache/hyprsunset-active-temp  (currently applied K value)
# Transition PID: ~/.cache/hyprsunset-transition.pid
{ pkgs, lib, customConfig, ... }:

let
  hasHyprsunset  = customConfig.homeManager.services.hyprsunset.enable;
  cfg            = customConfig.homeManager.services.hyprsunset;

  dayTemp        = toString cfg.dayTemp;
  defaultNight   = toString cfg.nightTemp;
  dayStart       = toString cfg.dayStartHour;
  nightStart     = toString cfg.nightStartHour;
  transitionSecs = toString (cfg.transitionMinutes * 60);

  hyprctl       = "${pkgs.hyprland}/bin/hyprctl";
  hyprsunsetBin = "${pkgs.hyprsunset}/bin/hyprsunset";

  # ---- hyprsunset-schedule ------------------------------------------------
  # Called ONLY by the systemd timer. Performs a gradual transition from the
  # currently active temperature to the time-of-day target over transitionMinutes.
  # The daemon stays running throughout — no CTM flash.
  hyprsunsetScheduleScript = pkgs.writeShellScriptBin "hyprsunset-schedule" ''
    if [ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]; then exit 0; fi

    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    OLD_STATE="$HOME/.cache/gammastep-state"
    if [ -f "$OLD_STATE" ] && [ ! -f "$STATE_FILE" ]; then
      mv "$OLD_STATE" "$STATE_FILE"
    fi

    [ ! -f "$STATE_FILE" ] && echo "${defaultNight}:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"

    if [ "$MODE" = "enabled" ]; then
      MODE="auto"
      echo "''${TEMP}:auto" > "$STATE_FILE"
    fi

    [ "$MODE" = "disabled" ] || [ "$MODE" = "manual" ] && exit 0

    HOUR=$(date +%-H)
    if [ "$HOUR" -ge ${dayStart} ] && [ "$HOUR" -lt ${nightStart} ]; then
      TARGET=${dayTemp}
    else
      TARGET="''${TEMP}"
    fi

    ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "''${TARGET}")

    if [ "$ACTIVE" = "$TARGET" ]; then
      pkill -RTMIN+12 waybar 2>/dev/null || true
      exit 0
    fi

    # Kill any in-progress transition
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    # Ensure hyprsunset daemon is running before transitioning
    if ! pkill -0 -x hyprsunset 2>/dev/null; then
      ${hyprsunsetBin} --temperature "$ACTIVE" &
      disown
      sleep 0.3
    fi

    STEPS=30
    INTERVAL=$(( ${transitionSecs} / STEPS ))
    A=$ACTIVE
    T=$TARGET

    (
      echo $BASHPID > "$PID_FILE"
      for i in $(seq 1 $STEPS); do
        STEP=$(( A + (T - A) * i / STEPS ))
        ${hyprctl} hyprsunset temperature "$STEP" >/dev/null 2>&1 || true
        echo "$STEP" > "$ACTIVE_FILE"
        pkill -RTMIN+12 waybar 2>/dev/null || true
        [ "$i" -lt "$STEPS" ] && sleep "$INTERVAL"
      done
      rm -f "$PID_FILE"
    ) &
    disown
  '';

  # ---- hyprsunset-init ----------------------------------------------------
  # Called from Hyprland exec-once. Starts the daemon at the correct temperature
  # INSTANTLY (no gradual transition — restoring state after login).
  hyprsunsetInitScript = pkgs.writeShellScriptBin "hyprsunset-init" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"

    OLD_STATE="$HOME/.cache/gammastep-state"
    if [ -f "$OLD_STATE" ] && [ ! -f "$STATE_FILE" ]; then
      mv "$OLD_STATE" "$STATE_FILE"
    fi

    [ ! -f "$STATE_FILE" ] && echo "${defaultNight}:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"

    if [ "$MODE" = "enabled" ]; then
      MODE="auto"
      echo "''${TEMP}:auto" > "$STATE_FILE"
    fi

    HOUR=$(date +%-H)
    if [ "$MODE" = "disabled" ]; then
      APPLY=${dayTemp}
    elif [ "$MODE" = "auto" ] && [ "$HOUR" -ge ${dayStart} ] && [ "$HOUR" -lt ${nightStart} ]; then
      APPLY=${dayTemp}
    else
      APPLY="''${TEMP}"
    fi

    # Start daemon if not running, otherwise update in-place (no CTM flash)
    if ! pkill -0 -x hyprsunset 2>/dev/null; then
      ${hyprsunsetBin} --temperature "$APPLY" &
      disown
      sleep 0.3
    else
      ${hyprctl} hyprsunset temperature "$APPLY" >/dev/null 2>&1 || true
    fi

    echo "$APPLY" > "$ACTIVE_FILE"
    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

in
{
  home.packages = lib.mkIf hasHyprsunset [
    pkgs.hyprsunset
    hyprsunsetInitScript
    hyprsunsetScheduleScript
  ];

  systemd.user.services.hyprsunset-schedule = lib.mkIf hasHyprsunset {
    Unit = {
      Description = "Apply scheduled hyprsunset color temperature transition";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hyprsunsetScheduleScript}/bin/hyprsunset-schedule";
      KillMode = "none";  # Allow background transition subshell to outlive the oneshot
    };
  };

  systemd.user.timers.hyprsunset-schedule = lib.mkIf hasHyprsunset {
    Unit = {
      Description = "Hyprsunset day/night schedule timer";
    };
    Timer = {
      OnCalendar = [
        "*-*-* ${toString cfg.dayStartHour}:00:00"   # Morning: start day transition
        "*-*-* ${toString cfg.nightStartHour}:00:00"  # Evening: start night transition
      ];
      Persistent = true;  # Fire on session start if a transition was missed
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
