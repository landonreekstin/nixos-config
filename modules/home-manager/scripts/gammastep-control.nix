# ~/nixos-config/modules/home-manager/scripts/gammastep-control.nix
#
# gammastep-init: restores the saved temperature on Hyprland login via exec-once.
# hyprsunset-schedule: applies day (6500K) or night (preset temp) based on time of day.
#   Called by systemd timer at 07:00 and 20:00, and by gammastep-init on login.
# The adjust/toggle scripts live inline in waybar/functional.nix so they can be
# referenced by full Nix store path in the waybar config (avoids PATH ambiguity).
{ pkgs, lib, customConfig, ... }:

let
  hasGammastep = customConfig.homeManager.services.gammastep.enable;

  # Shared day/night constants — keep in sync with waybar/functional.nix scripts
  dayStart = "7";   # 07:00 — switch to 6500K
  nightStart = "20"; # 20:00 — switch to night preset

  hyprsunsetScheduleScript = pkgs.writeShellScriptBin "hyprsunset-schedule" ''
    # Only run inside a Hyprland session
    if [ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]; then
      exit 0
    fi

    STATE_FILE="$HOME/.cache/gammastep-state"

    if [ ! -f "$STATE_FILE" ]; then
      echo "2500:enabled" > "$STATE_FILE"
    fi

    STATE_LINE=$(cat "$STATE_FILE")
    TEMP="''${STATE_LINE%%:*}"
    STATUS="''${STATE_LINE##*:}"

    if [ "$STATUS" != "enabled" ]; then
      exit 0
    fi

    HOUR=$(date +%-H)

    pkill -x hyprsunset 2>/dev/null || true
    sleep 0.2

    if [ "$HOUR" -ge ${dayStart} ] && [ "$HOUR" -lt ${nightStart} ]; then
      # Daytime — neutral color temperature
      ${pkgs.hyprsunset}/bin/hyprsunset -t 6500 &
    else
      # Nighttime — apply user's preset
      ${pkgs.hyprsunset}/bin/hyprsunset -t "''${TEMP}" &
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  gammastepInitScript = pkgs.writeShellScriptBin "gammastep-init" ''
    STATE_FILE="$HOME/.cache/gammastep-state"

    if [ ! -f "$STATE_FILE" ]; then
      echo "2500:enabled" > "$STATE_FILE"
    fi

    # Delegate to the schedule script — it applies the correct day/night temperature
    ${hyprsunsetScheduleScript}/bin/hyprsunset-schedule
  '';

in
{
  home.packages = lib.mkIf hasGammastep [
    gammastepInitScript
    hyprsunsetScheduleScript
  ];

  systemd.user.services.hyprsunset-schedule = lib.mkIf hasGammastep {
    Unit = {
      Description = "Apply scheduled hyprsunset color temperature";
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
        "*-*-* 07:00:00"  # Morning: switch to 6500K
        "*-*-* 20:00:00"  # Evening: switch to night preset
      ];
      Persistent = true;  # Fire on session start if transition was missed
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
