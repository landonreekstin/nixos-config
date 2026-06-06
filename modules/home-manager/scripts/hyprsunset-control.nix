# ~/nixos-config/modules/home-manager/scripts/hyprsunset-control.nix
#
# hyprsunset-init: applies correct temperature instantly on Hyprland login (exec-once).
# hyprsunset-schedule: performs a GRADUAL transition to the time-of-day target.
#   Only called by the systemd timer at dayStartHour and nightStartHour.
#   All user interactions (waybar scroll/click) are instant — see waybar/functional.nix.
#
# State file: ~/.cache/hyprsunset-state  format: "NIGHT_TEMP:MODE"
#   MODE: auto | manual | disabled
# Active temp: ~/.cache/hyprsunset-active-temp  (currently applied K value)
# Transition PID: ~/.cache/hyprsunset-transition.pid
{ pkgs, lib, customConfig, ... }:

let
  hasHyprsunset   = customConfig.homeManager.services.hyprsunset.enable;
  cfg             = customConfig.homeManager.services.hyprsunset;

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

    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    apply_temp() {
      local T="$1"
      if [ "$T" -ge ${dayTemp} ]; then
        ${pkgs.hyprland}/bin/hyprctl keyword decoration:screen_shader "" 2>/dev/null || true; return
      fi
      local F="$HOME/.cache/hyprsunset-shader.glsl"
      read -r R G B <<< "$(${pkgs.gawk}/bin/awk -v t="$T" 'BEGIN {
        t/=100; r=1; g=1; b=1
        if (t<=66) {
          g=(99.4708025861*log(t)-161.1195681661)/255; if(g<0)g=0; if(g>1)g=1
          b=t>19?(138.5177312231*log(t-10)-305.0447927307)/255:0; if(b<0)b=0; if(b>1)b=1
        } else {
          r=(329.698727446*(t-60)^-0.1332047592)/255; if(r<0)r=0; if(r>1)r=1
          g=(288.1221695283*(t-60)^-0.0755148492)/255; if(g<0)g=0; if(g>1)g=1; b=1
        }
        printf "%.6f %.6f %.6f\n",r,g,b
      }')"
      printf '#version 320 es\nprecision highp float;\nin vec2 v_texcoord;\nuniform sampler2D tex;\nout vec4 fragColor;\nvoid main(){\n  vec4 c=texture(tex,v_texcoord);\n  c.r*=%s; c.g*=%s; c.b*=%s;\n  fragColor=c;\n}\n' "$R" "$G" "$B" > "$F"
      ${pkgs.hyprland}/bin/hyprctl keyword decoration:screen_shader "$F" 2>/dev/null || true
    }

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

    # Kill any lingering hyprsunset from the old approach
    pkill -9 -x hyprsunset 2>/dev/null || true

    STEPS=30
    INTERVAL=$(( ${transitionSecs} / STEPS ))
    A=$ACTIVE
    T=$TARGET

    (
      echo $BASHPID > "$PID_FILE"
      for i in $(seq 1 $STEPS); do
        STEP=$(( A + (T - A) * i / STEPS ))
        apply_temp "$STEP"
        echo "$STEP" > "$ACTIVE_FILE"
        pkill -RTMIN+12 waybar 2>/dev/null || true
        [ "$i" -lt "$STEPS" ] && sleep "$INTERVAL"
      done
      rm -f "$PID_FILE"
    ) &
    disown
  '';

  # ---- hyprsunset-init ----------------------------------------------------
  # Called from Hyprland exec-once. Applies the correct temperature INSTANTLY
  # (no gradual transition — we're restoring state after login).
  hyprsunsetInitScript = pkgs.writeShellScriptBin "hyprsunset-init" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"

    apply_temp() {
      local T="$1"
      if [ "$T" -ge ${dayTemp} ]; then
        ${pkgs.hyprland}/bin/hyprctl keyword decoration:screen_shader "" 2>/dev/null || true; return
      fi
      local F="$HOME/.cache/hyprsunset-shader.glsl"
      read -r R G B <<< "$(${pkgs.gawk}/bin/awk -v t="$T" 'BEGIN {
        t/=100; r=1; g=1; b=1
        if (t<=66) {
          g=(99.4708025861*log(t)-161.1195681661)/255; if(g<0)g=0; if(g>1)g=1
          b=t>19?(138.5177312231*log(t-10)-305.0447927307)/255:0; if(b<0)b=0; if(b>1)b=1
        } else {
          r=(329.698727446*(t-60)^-0.1332047592)/255; if(r<0)r=0; if(r>1)r=1
          g=(288.1221695283*(t-60)^-0.0755148492)/255; if(g<0)g=0; if(g>1)g=1; b=1
        }
        printf "%.6f %.6f %.6f\n",r,g,b
      }')"
      printf '#version 320 es\nprecision highp float;\nin vec2 v_texcoord;\nuniform sampler2D tex;\nout vec4 fragColor;\nvoid main(){\n  vec4 c=texture(tex,v_texcoord);\n  c.r*=%s; c.g*=%s; c.b*=%s;\n  fragColor=c;\n}\n' "$R" "$G" "$B" > "$F"
      ${pkgs.hyprland}/bin/hyprctl keyword decoration:screen_shader "$F" 2>/dev/null || true
    }

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

    # Kill any lingering hyprsunset from the old approach
    pkill -9 -x hyprsunset 2>/dev/null || true

    if [ "$MODE" = "disabled" ]; then
      ${pkgs.hyprland}/bin/hyprctl keyword decoration:screen_shader "" 2>/dev/null || true
      exit 0
    fi

    # Determine what to apply immediately
    HOUR=$(date +%-H)
    if [ "$MODE" = "auto" ] && [ "$HOUR" -ge ${dayStart} ] && [ "$HOUR" -lt ${nightStart} ]; then
      APPLY=${dayTemp}
    else
      APPLY="''${TEMP}"
    fi

    apply_temp "$APPLY"
    echo "$APPLY" > "$ACTIVE_FILE"
    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

in
{
  home.packages = lib.mkIf hasHyprsunset [
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
      Persistent = true;  # Fire on session start if a transition was missed (e.g. resume from sleep)
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
