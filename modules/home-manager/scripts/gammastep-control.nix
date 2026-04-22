# ~/nixos-config/modules/home-manager/scripts/gammastep-control.nix
#
# gammastep-init: applies correct temperature instantly on Hyprland login (exec-once).
# hyprsunset-schedule: performs a GRADUAL transition to the time-of-day target.
#   Only called by the systemd timer at dayStartHour and nightStartHour.
#   All user interactions (waybar scroll/click) are instant — see waybar/functional.nix.
#
# State file: ~/.cache/gammastep-state  format: "NIGHT_TEMP:MODE"
#   MODE: auto | manual | disabled
# Active temp: ~/.cache/hyprsunset-active-temp  (currently applied K value)
# Transition PID: ~/.cache/hyprsunset-transition.pid
{ pkgs, lib, customConfig, ... }:

let
  hasGammastep = customConfig.homeManager.services.gammastep.enable;
  cfg          = customConfig.homeManager.services.gammastep;

  # Bake config constants into scripts at build time
  dayTemp         = toString cfg.dayTemp;
  defaultNight    = toString cfg.nightTemp;
  dayStart        = toString cfg.dayStartHour;
  nightStart      = toString cfg.nightStartHour;
  transitionSecs  = toString (cfg.transitionMinutes * 60);

  # ---- hyprsunset-schedule ------------------------------------------------
  # Called ONLY by the systemd timer. Performs a gradual transition from the
  # currently active temperature to the time-of-day target over transitionMinutes.
  hyprsunsetScheduleScript = pkgs.writeShellScriptBin "hyprsunset-schedule" ''
    if [ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]; then exit 0; fi

    STATE_FILE="$HOME/.cache/gammastep-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    [ ! -f "$STATE_FILE" ] && echo "${defaultNight}:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"

    # Migrate from old 'enabled' format
    if [ "$MODE" = "enabled" ]; then
      MODE="auto"
      echo "''${TEMP}:auto" > "$STATE_FILE"
    fi

    # Only auto mode follows the schedule
    [ "$MODE" = "disabled" ] || [ "$MODE" = "manual" ] && exit 0

    # Determine target temperature for the current time
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

    STEPS=30
    INTERVAL=$(( ${transitionSecs} / STEPS ))
    A=$ACTIVE
    T=$TARGET

    (
      echo $BASHPID > "$PID_FILE"
      for i in $(seq 1 $STEPS); do
        STEP=$(( A + (T - A) * i / STEPS ))
        pkill -x hyprsunset 2>/dev/null || true
        sleep 0.1
        ${pkgs.hyprsunset}/bin/hyprsunset -t "$STEP" &
        echo "$STEP" > "$ACTIVE_FILE"
        pkill -RTMIN+12 waybar 2>/dev/null || true
        [ "$i" -lt "$STEPS" ] && sleep "$INTERVAL"
      done
      rm -f "$PID_FILE"
    ) &
    disown
  '';

  # ---- gammastep-init -----------------------------------------------------
  # Called from Hyprland exec-once. Applies the correct temperature INSTANTLY
  # (no gradual transition — we're restoring state after login).
  gammastepInitScript = pkgs.writeShellScriptBin "gammastep-init" ''
    STATE_FILE="$HOME/.cache/gammastep-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"

    [ ! -f "$STATE_FILE" ] && echo "${defaultNight}:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"

    # Migrate from old 'enabled' format
    if [ "$MODE" = "enabled" ]; then
      MODE="auto"
      echo "''${TEMP}:auto" > "$STATE_FILE"
    fi

    [ "$MODE" = "disabled" ] && exit 0

    # Determine what to apply immediately
    HOUR=$(date +%-H)
    if [ "$MODE" = "auto" ] && [ "$HOUR" -ge ${dayStart} ] && [ "$HOUR" -lt ${nightStart} ]; then
      APPLY=${dayTemp}
    else
      APPLY="''${TEMP}"
    fi

    pkill -x hyprsunset 2>/dev/null || true
    sleep 0.2
    ${pkgs.hyprsunset}/bin/hyprsunset -t "$APPLY" &
    echo "$APPLY" > "$ACTIVE_FILE"
    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

in
{
  home.packages = lib.mkIf hasGammastep [
    gammastepInitScript
    hyprsunsetScheduleScript
  ];

  systemd.user.services.hyprsunset-schedule = lib.mkIf hasGammastep {
    Unit = {
      Description = "Apply scheduled hyprsunset color temperature transition";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hyprsunsetScheduleScript}/bin/hyprsunset-schedule";
    };
  };

  systemd.user.timers.hyprsunset-schedule = lib.mkIf hasGammastep {
    Unit = {
      Description = "Hyprsunset day/night schedule timer";
    };
    Timer = {
      OnCalendar = [
        "*-*-* ${toString cfg.dayStartHour}:00:00"   # Morning: start day transition
        "*-*-* ${toString cfg.nightStartHour}:00:00"  # Evening: start night transition
      ];
      Persistent = true;  # Fire on session start if a transition was missed (e.g. resume from sleep)
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
