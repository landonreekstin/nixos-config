# ~/nixos-config/modules/home-manager/hyprland/screen-light.nix
# Screen lighting that follows the sun and the weather
# (customConfig.homeManager.services.screenLight).
#
# A small user daemon, re-evaluated every 20 s:
#   - time of day: real sunrise/sunset from Open-Meteo (no API key) at the configured
#     coordinates; bright and neutral by day, dimmer and warmer at night, with an hour-long
#     ramp centred on sunrise and sunset;
#   - weather (fetched every 15 min, same request): sunny days get brighter, cloudy days a
#     little dimmer/warmer, rain/snow/storms more so. Weather only matters in daylight;
#   - a fullscreen window on the focused screen: a video player or browser ("movie") keeps
#     the brightness but caps the warmth; anything else ("game") gets true colours and a
#     brightness boost.
#
# Brightness goes to the real backlight over DDC/CI (ddcutil) on the first screen that
# answers; screens that don't get software dimming instead. Warmth is software on every
# screen. Both software parts go through wl-gammarelay-rs (screen-dim.nix), whose gamma
# ramps stack with — so must not be combined with — hyprsunset's colour matrix.
#
# DDC needs /dev/i2c-* access for the logged-in user: the host adds ddcutil's udev rules.
# Last applied state is written to $XDG_STATE_HOME/screen-light/status for debugging.
{ config, pkgs, lib, customConfig, ... }:

let
  cfg = customConfig.homeManager.services.screenLight;
  on = lib.elem "hyprland" customConfig.desktop.environments && cfg.enable;
  desktopLib = import ./desktops/lib.nix { inherit lib; };

  screenLight = pkgs.writeShellApplication {
    name = "screen-light";
    runtimeInputs = with pkgs; [ curl jq ddcutil systemd hyprland gawk coreutils ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/screen-light"
      mkdir -p "$state"
      wx="$state/weather.json"
      url='https://api.open-meteo.com/v1/forecast?latitude=${cfg.latitude}&longitude=${cfg.longitude}&current=weather_code,cloud_cover&daily=sunrise,sunset&timezone=auto&forecast_days=1'
      bus=rs.wl-gammarelay
      iface=rs.wl.gammarelay

      # The DDC-capable screen: its i2c bus and its connector name (e.g. DP-1).
      ddc_bus=""; ddc_out=""
      find_ddc() {
        local info
        info=$(ddcutil detect --terse 2>/dev/null \
          | awk '/^Display/ { d = 1 } d && /I2C bus:/ { sub(/.*i2c-/, ""); b = $0 }
                 d && /DRM connector:/ { sub(/.*card[0-9]+-/, ""); print b, $0; exit }') || true
        ddc_bus=''${info%% *}; ddc_out=''${info#* }
        [ -n "$info" ] || { ddc_bus=""; ddc_out=""; }
      }

      fetch_weather() {
        if [ -z "$(find "$wx" -mmin -15 2>/dev/null)" ]; then
          if curl -sf --max-time 10 "$url" > "$wx.tmp"; then mv "$wx.tmp" "$wx"; else rm -f "$wx.tmp"; fi
        fi
      }

      # Prints: <brightness 0-100> <temperature K> <label>
      target() {
        local now sr ss code cloud fs mode
        now=$(date +%s)
        if [ -s "$wx" ]; then
          sr=$(date -d "$(jq -r '.daily.sunrise[0]' "$wx")" +%s 2>/dev/null || echo "")
          ss=$(date -d "$(jq -r '.daily.sunset[0]' "$wx")" +%s 2>/dev/null || echo "")
          code=$(jq -r '.current.weather_code // 0' "$wx")
          cloud=$(jq -r '.current.cloud_cover // 50' "$wx")
        fi
        # No weather yet (offline): fixed 7:00 sunrise / 18:00 sunset, no weather effect.
        [ -n "''${sr:-}" ] || sr=$(date -d 07:00 +%s)
        [ -n "''${ss:-}" ] || ss=$(date -d 18:00 +%s)
        code=''${code:-0}; cloud=''${cloud:-50}

        fs=$(hyprctl activewindow -j 2>/dev/null \
          | jq -r '(.fullscreen | tostring) as $f
                   | if ($f == "2" or $f == "3" or $f == "true") then (.class | ascii_downcase) else "" end' \
          2>/dev/null) || fs=""
        mode=normal
        if [ -n "$fs" ]; then
          case "$fs" in
            ${cfg.movieClasses}) mode=movie ;;
            *) mode=game ;;
          esac
        fi

        awk -v now="$now" -v sr="$sr" -v ss="$ss" -v code="$code" -v cloud="$cloud" -v mode="$mode" '
          function clamp(x, lo, hi) { return x < lo ? lo : (x > hi ? hi : x) }
          BEGIN {
            # Daylight 0..1, ramping over the hour centred on sunrise and on sunset.
            f = clamp((now - (sr - 1800)) / 3600, 0, 1)
            g = clamp(((ss + 1800) - now) / 3600, 0, 1)
            if (g < f) f = g
            b = ${toString cfg.nightBrightness} + f * (${toString cfg.dayBrightness} - ${toString cfg.nightBrightness})
            t = ${toString cfg.nightTemp} + f * (6500 - ${toString cfg.nightTemp})
            if (code >= 51)                                   { sky = "rainy";  db = -15; dt = -500 }
            else if (cloud >= 70 || code == 3 || code == 45 || code == 48) { sky = "cloudy"; db = -10; dt = -300 }
            else if (cloud < 30 && code <= 1)                 { sky = "sunny";  db = 20;  dt = 0 }
            else                                              { sky = "partly cloudy"; db = 0; dt = 0 }
            b += f * db; t += f * dt
            when = f >= 1 ? "day" : (f <= 0 ? "night" : "sunrise/sunset")
            if (mode == "game")  { t = 6500; b = clamp(b + 15, 0, 90) }
            if (mode == "movie") { if (t < 5500) t = 5500 }
            printf "%d %d %s, %s, %s\n", clamp(b, 10, 100) + 0.5, clamp(t, 2500, 6500) + 0.5, when, sky, mode
          }'
      }

      # Move a toward b by at most step.
      approach() { awk -v a="$1" -v b="$2" -v s="$3" 'BEGIN { d = b - a; if (d > s) d = s; if (d < -s) d = -s; printf "%d\n", a + d }'; }

      apply() {
        local b=$1 t=$2 out soft
        if [ -n "$ddc_bus" ] && [ "$b" != "$last_ddc" ]; then
          if ddcutil --bus "$ddc_bus" setvcp 10 "$b" >/dev/null 2>&1; then last_ddc=$b; else find_ddc; fi
        fi
        # Screens without DDC: software dimming, gentler than a real backlight.
        soft=$(awk -v b="$b" 'BEGIN { printf "%.2f", 0.6 + 0.4 * b / 100 }')
        for out in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name'); do
          busctl --user set-property "$bus" "/outputs/''${out//-/_}" "$iface" Temperature q "$t" 2>/dev/null || true
          if [ "$out" != "$ddc_out" ]; then
            busctl --user set-property "$bus" "/outputs/''${out//-/_}" "$iface" Brightness d "$soft" 2>/dev/null || true
          fi
        done
      }

      find_ddc
      cur_b=""; cur_t=""; last_ddc=""; last_mode=""; tick=0
      while true; do
        fetch_weather
        read -r tb tt label < <(target)
        mode=''${label##*, }
        if [ -z "$cur_b" ] || [ "$mode" != "$last_mode" ]; then
          nb=$tb; nt=$tt          # first run, or a game/movie started or ended: jump
        else
          nb=$(approach "$cur_b" "$tb" 2); nt=$(approach "$cur_t" "$tt" 100)
        fi
        # Re-assert every 5 min too: the gamma daemon or a screen may have restarted.
        if [ "$nb" != "$cur_b" ] || [ "$nt" != "$cur_t" ] || [ $((tick % 15)) -eq 0 ]; then
          [ $((tick % 15)) -eq 0 ] && last_ddc=""
          apply "$nb" "$nt"
        fi
        cur_b=$nb; cur_t=$nt; last_mode=$mode; tick=$((tick + 1))
        echo "$(date '+%F %T') brightness=$cur_b temp=''${cur_t}K target=$tb/''${tt}K ($label) ddc=''${ddc_out:-none}" > "$state/status"
        sleep 20
      done
    '';
  };
in
{
  config = lib.mkIf on {
    assertions = [{
      assertion = customConfig.homeManager.services.screenDim.enable
        && !customConfig.homeManager.services.hyprsunset.enable;
      message = "screenLight needs screenDim (wl-gammarelay) on and hyprsunset off.";
    }];

    home.packages = [ screenLight ];

    systemd.user.services.screen-light = {
      Unit = {
        Description = "Screen brightness and warmth from time of day and weather";
        BindsTo = [ "hypr-desktop-session.service" ];
        Wants = [ "wl-gammarelay.service" ];
        After = [ "hypr-desktop-session.service" "wl-gammarelay.service" ];
      };
      Service = {
        ExecStart = "${screenLight}/bin/screen-light";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = map desktopLib.target customConfig.homeManager.hyprland.desktops.enabled;
    };
  };
}
