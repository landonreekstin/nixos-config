# ~/nixos-config/modules/home-manager/scripts/hyprsunset-control.nix
#
# hyprsunset-init:       applies the correct temperature instantly on Hyprland login (exec-once).
# hyprsunset-schedule:   reconciler run every 5 minutes by hyprsunset-schedule.timer. Works out
#   the time-of-day target (boundary from hyprsunset-isday, see hyprsunset-solar.nix) and hands
#   a GRADUAL transition to hyprsunset-transition.service whenever the applied temperature does
#   not match it. Polling rather than firing once at each boundary is what makes the schedule
#   self-healing: it also catches resume-from-suspend, a crashed hyprsunset, and the moment the
#   waybar widget is switched back to auto.
# hyprsunset-transition: the gradual walk itself. Runs in the FOREGROUND under
#   hyprsunset-transition.service so systemd owns its lifecycle — `systemctl --user restart`
#   retargets it and `stop` cancels it, which is why there is no longer a PID file or a
#   disowned subshell escaping a oneshot via the deprecated KillMode=none.
#   All user interactions (waybar scroll/click) stay instant — see waybar/functional.nix.
#
# State file: ~/.cache/hyprsunset-state  format: "NIGHT_TEMP:MODE"
#   MODE: auto | manual | disabled
# Active temp: ~/.cache/hyprsunset-active-temp  (currently applied K value)
# Walk target: ~/.cache/hyprsunset-target       (K value hyprsunset-transition is walking to)
{ pkgs, lib, customConfig, ... }:

let
  hasHyprsunset   = customConfig.homeManager.services.hyprsunset.enable;
  cfg             = customConfig.homeManager.services.hyprsunset;

  # Bake config constants into scripts at build time
  dayTemp         = toString cfg.dayTemp;
  defaultNight    = toString cfg.nightTemp;
  transitionSecs  = toString (cfg.transitionMinutes * 60);

  systemctl       = "${pkgs.systemd}/bin/systemctl";

  # Shared day/night predicate (solar, with the fixed hours as fallback)
  isDay = "${import ./hyprsunset-solar.nix { inherit pkgs cfg; }}/bin/hyprsunset-isday";

  # Read ~/.cache/hyprsunset-state into TEMP/MODE, migrating the two older layouts
  readState = ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    TARGET_FILE="$HOME/.cache/hyprsunset-target"

    # Migrate state file from old gammastep location
    OLD_STATE="$HOME/.cache/gammastep-state"
    if [ -f "$OLD_STATE" ] && [ ! -f "$STATE_FILE" ]; then
      mv "$OLD_STATE" "$STATE_FILE"
    fi

    [ ! -f "$STATE_FILE" ] && echo "${defaultNight}:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"

    # Migrate from old 'enabled' format
    if [ "$MODE" = "enabled" ]; then
      MODE="auto"
      echo "''${TEMP}:auto" > "$STATE_FILE"
    fi
  '';

  # ---- hyprsunset-schedule ------------------------------------------------
  # The 5-minute reconciler. Decides the target and delegates the walk.
  hyprsunsetScheduleScript = pkgs.writeShellScriptBin "hyprsunset-schedule" ''
    if [ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]; then exit 0; fi

    ${readState}

    # Only auto mode follows the schedule
    if [ "$MODE" = "disabled" ] || [ "$MODE" = "manual" ]; then exit 0; fi

    # Determine target temperature for the current side of the boundary
    if [ "$(${isDay})" = "1" ]; then
      TARGET=${dayTemp}
    else
      TARGET="''${TEMP}"
    fi

    ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "''${TARGET}")

    if [ "$ACTIVE" = "$TARGET" ]; then
      pkill -RTMIN+12 waybar 2>/dev/null || true
      exit 0
    fi

    # A walk toward this same target is already in flight — let it finish
    # rather than restarting it from the top on every poll.
    if [ "$(cat "$TARGET_FILE" 2>/dev/null)" = "$TARGET" ] \
       && ${systemctl} --user is-active --quiet hyprsunset-transition.service; then
      exit 0
    fi

    echo "$TARGET" > "$TARGET_FILE"
    ${systemctl} --user restart --no-block hyprsunset-transition.service
  '';

  # ---- hyprsunset-transition ----------------------------------------------
  # ExecStart of hyprsunset-transition.service. Walks the active temperature to
  # whatever ~/.cache/hyprsunset-target says over transitionMinutes.
  hyprsunsetTransitionScript = pkgs.writeShellScriptBin "hyprsunset-transition" ''
    if [ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]; then exit 0; fi

    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    TARGET_FILE="$HOME/.cache/hyprsunset-target"

    TARGET=$(cat "$TARGET_FILE" 2>/dev/null) || exit 0
    [ -z "$TARGET" ] && exit 0

    ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "''${TARGET}")
    [ "$ACTIVE" = "$TARGET" ] && exit 0

    SOCK="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.hyprsunset.sock"

    # Socket IPC keeps the CTM continuous; restarting hyprsunset per step flashes
    # the screen, so only fall back to that when there is no socket to talk to.
    if [ ! -S "$SOCK" ]; then
      pkill -9 -x hyprsunset 2>/dev/null || true
      ${pkgs.hyprsunset}/bin/hyprsunset -t "$ACTIVE" &
      sleep 0.5
    fi

    STEPS=30
    INTERVAL=$(( ${transitionSecs} / STEPS ))

    for i in $(seq 1 $STEPS); do
      STEP=$(( ACTIVE + (TARGET - ACTIVE) * i / STEPS ))
      if [ -S "$SOCK" ]; then
        echo "temperature $STEP" | ${pkgs.socat}/bin/socat - UNIX-CONNECT:"$SOCK" 2>/dev/null || true
      else
        pkill -9 -x hyprsunset 2>/dev/null || true
        ${pkgs.hyprsunset}/bin/hyprsunset -t "$STEP" &
        sleep 0.3
      fi
      echo "$STEP" > "$ACTIVE_FILE"
      pkill -RTMIN+12 waybar 2>/dev/null || true
      [ "$i" -lt "$STEPS" ] && sleep "$INTERVAL"
    done

    exit 0
  '';

  # ---- hyprsunset-init ----------------------------------------------------
  # Called from Hyprland exec-once. Applies the correct temperature INSTANTLY
  # (no gradual transition — we're restoring state after login).
  hyprsunsetInitScript = pkgs.writeShellScriptBin "hyprsunset-init" ''
    ${readState}

    rm -f "$HOME/.cache/hyprsunset-transition.pid"  # pre-poll layout

    [ "$MODE" = "disabled" ] && exit 0

    # Determine what to apply immediately
    if [ "$MODE" = "auto" ] && [ "$(${isDay})" = "1" ]; then
      APPLY=${dayTemp}
    else
      APPLY="''${TEMP}"
    fi

    pkill -9 -x hyprsunset 2>/dev/null || true
    ${pkgs.hyprsunset}/bin/hyprsunset -t "$APPLY" &
    echo "$APPLY" > "$ACTIVE_FILE"
    echo "$APPLY" > "$TARGET_FILE"
    pkill -RTMIN+12 waybar 2>/dev/null || true
    exit 0
  '';

in
{
  home.packages = lib.mkIf hasHyprsunset [
    hyprsunsetInitScript
    hyprsunsetScheduleScript
    hyprsunsetTransitionScript
    (import ./hyprsunset-solar.nix { inherit pkgs cfg; })
    pkgs.socat
  ];

  systemd.user.services.hyprsunset-schedule = lib.mkIf hasHyprsunset {
    Unit = {
      Description = "Reconcile hyprsunset color temperature with the time of day";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hyprsunsetScheduleScript}/bin/hyprsunset-schedule";
    };
  };

  systemd.user.services.hyprsunset-transition = lib.mkIf hasHyprsunset {
    Unit = {
      Description = "Gradual hyprsunset color temperature transition";
    };
    Service = {
      ExecStart = "${hyprsunsetTransitionScript}/bin/hyprsunset-transition";
      # The walk sleeps between steps, so a retarget is `systemctl restart` and a
      # cancel is `stop`. KillMode=process so that a hyprsunset started by the
      # no-socket fallback above is not taken down with the script; the cost is
      # that a cancel orphans the current `sleep` for up to one step (≤60s) and
      # systemd logs one "Unit process remains running" line about it. Harmless —
      # a restart works with that leftover in the cgroup.
      KillMode = "process";
    };
  };

  systemd.user.timers.hyprsunset-schedule = lib.mkIf hasHyprsunset {
    Unit = {
      Description = "Hyprsunset day/night reconcile timer";
    };
    Timer = {
      # Poll rather than fire at two fixed times: the boundary now moves with the
      # sun, and a poll also recovers from suspend, a crash, or a mode change.
      OnCalendar = [ "*:0/5" ];
      AccuracySec = "30s";
      Persistent = true;  # reconcile immediately at session start / after a missed poll
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
