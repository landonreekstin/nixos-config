# ~/nixos-config/modules/home-manager/de-wm-components/waybar/functional.nix
{ config, pkgs, lib, customConfig, ... }:

let

  isHyprlandHost = lib.elem "hyprland" customConfig.desktop.environments;
  launcherEnabled = customConfig.desktop.hyprland.launcher.enable;
  pinnedApps = customConfig.desktop.hyprland.launcher.pinnedApps;
  hasScreenBacklight = customConfig.hardware.display.backlight.enable;
  hasKbdBacklight = customConfig.hardware.kbdBacklight.enable;
  hasBattery = customConfig.hardware.battery.enable;
  hasVpnClient = customConfig.services.wireguard.client.enable;
  hasWeather = customConfig.desktop.hyprland.weather.enable;
  hasHyprsunset = customConfig.homeManager.services.hyprsunset.enable;
  hasCkbNext = customConfig.hardware.peripherals.ckb-next.enable;
  ckbScripts = import ../../themes/century-series/ckb-scripts.nix { inherit pkgs; };
  weatherLocation = customConfig.desktop.hyprland.weather.location;
  weatherUseFahrenheit = customConfig.desktop.hyprland.weather.useFahrenheit;
  sinkMappings = customConfig.desktop.hyprland.audioSinkMappings;

  vpnInterface = customConfig.services.wireguard.client.interfaceName;

  # Shell case statements for sink description → icon/class, Nix-interpolated at build time
  audioMappingCases = lib.concatMapStrings (m: ''
    *"${m.match}"*)
      ICON="${m.icon}"; CLASS="${m.class}" ;;
  '') sinkMappings;

  weatherScript = pkgs.writeShellScript "waybar-weather" ''
    LOC="${weatherLocation}"
    URL="https://wttr.in/''${LOC}?format=j1"

    DATA=$(${pkgs.curl}/bin/curl -sf --max-time 10 "$URL" 2>/dev/null)
    if [ -z "$DATA" ]; then
      printf '{"text":"WX ERR","class":"error","tooltip":"Weather data unavailable"}'
      exit 0
    fi

    CODE=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].weatherCode')
    TEMP_F=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].temp_F')
    TEMP_C=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].temp_C')
    FEELS_F=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].FeelsLikeF')
    HUMIDITY=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].humidity')
    WIND=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].windspeedMiles')
    WIND_DIR=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].winddir16Point')
    DESC=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.current_condition[0].weatherDesc[0].value')
    AREA=$(printf '%s' "$DATA" | ${pkgs.jq}/bin/jq -r '.nearest_area[0].areaName[0].value // "UNKNOWN"')

    case "$CODE" in
      113)            ICON="☀";  CLASS="clear" ;;
      116)            ICON="⛅"; CLASS="partly-cloudy" ;;
      119|122)        ICON="☁";  CLASS="cloudy" ;;
      143|248|260)    ICON="≡";  CLASS="fog" ;;
      200|386|389)    ICON="⛈"; CLASS="storm" ;;
      179|182|185|281|284|311|314|317|320|323|326|329|332|335|338|350|371|374|377|392|395)
                      ICON="❄";  CLASS="snow" ;;
      176|263|266|293|296|299|302|305|308|353|356|359)
                      ICON="⛆"; CLASS="rain" ;;
      *)              ICON="?";  CLASS="unknown" ;;
    esac

    if [ "${toString weatherUseFahrenheit}" = "1" ]; then
      TEMP="''${TEMP_F}°F"
      FEELS="''${FEELS_F}°F"
    else
      TEMP="''${TEMP_C}°C"
      FEELS="''${FEELS_F}°F"
    fi

    TEXT="''${ICON} ''${TEMP}"
    TOOLTIP="WX: ''${DESC}\nTEMP: ''${TEMP_F}°F / ''${TEMP_C}°C\nFEELS: ''${FEELS}\nHUMID: ''${HUMIDITY}%\nWIND: ''${WIND}mph ''${WIND_DIR}\nLOC: ''${AREA}"

    printf '{"text":"%s","tooltip":"%s","class":"%s"}' "$TEXT" "$TOOLTIP" "$CLASS"
  '';

  audioStatusScript = pkgs.writeShellScript "waybar-audio-status" ''
    # Single-shot polling script (interval=2 + signal=11 for immediate scroll refresh).
    #
    # HDMI pro-audio sinks report hardware level (1.00 = 100%) when SUSPENDED because
    # WirePlumber hasn't initialized the mixer node yet. We detect this state, read the
    # stored volume from WirePlumber's routes file, and re-apply it via wpctl set-volume.
    # This one-time initialization means wpctl get-volume tracks correctly from then on,
    # so scroll events (which send SIGRTMIN+11 to refresh immediately) work without pavu.

    SINK=$(${pkgs.pulseaudio}/bin/pactl get-default-sink 2>/dev/null)
    WPVOL=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    VOLUME=$(echo "$WPVOL" | ${pkgs.gawk}/bin/awk '{printf "%d", $2 * 100}')
    VOLUME="''${VOLUME:-0}"
    if echo "$WPVOL" | grep -q "MUTED"; then MUTED=1; else MUTED=0; fi

    # HDMI sink uninitialized: read stored volume from WirePlumber routes file and re-apply.
    # The re-apply initializes wpctl so scroll updates work immediately via signal refresh.
    if [ "$VOLUME" -ge 99 ] && [ "$MUTED" -eq 0 ]; then
      SINK_STATE=$(${pkgs.pulseaudio}/bin/pactl list sinks short | \
        ${pkgs.gawk}/bin/awk -F'\t' -v s="$SINK" '$2==s{print $NF}')
      if [ "$SINK_STATE" = "SUSPENDED" ]; then
        ALSA_DEV=$(echo "$SINK" | grep -oE 'pro-output-[0-9]+' | grep -oE '[0-9]+$')
        if [ -n "$ALSA_DEV" ]; then
          DEVICE_ID=$(${pkgs.wireplumber}/bin/wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | \
            ${pkgs.gawk}/bin/awk '/ device\.id =/{gsub(/[^0-9]/,""); print; exit}')
          if [ -n "$DEVICE_ID" ]; then
            ROUTE_NAME=$(${pkgs.pipewire}/bin/pw-cli enum-params "$DEVICE_ID" \
              "Spa:Enum:ParamId:EnumRoute" 2>/dev/null | \
              ${pkgs.gawk}/bin/awk -v dev="$ALSA_DEV" '
                /Prop: key/ { in_devices = 0 }
                /Route:devices/ { in_devices = 1 }
                /String "hdmi-output-/ {
                  match($0, /hdmi-output-[0-9]+/)
                  current_route = substr($0, RSTART, RLENGTH)
                }
                in_devices && /^\s+Int [0-9]/ {
                  if ($NF == dev) found = current_route
                }
                END { print found }
              ')
            if [ -n "$ROUTE_NAME" ]; then
              CARD=$(echo "$SINK" | sed 's/^alsa_output\./alsa_card./; s/\.[^.]*$//')
              ROUTES_FILE="$HOME/.local/state/wireplumber/default-routes"
              STORED_VOL=$(grep -F "''${CARD}:output:''${ROUTE_NAME}=" "$ROUTES_FILE" 2>/dev/null | \
                sed 's/.*"channelVolumes":\[//' | cut -d',' -f1 | \
                ${pkgs.gawk}/bin/awk '{printf "%d", $1 * 100}')
              if [ -n "$STORED_VOL" ] && [ "$STORED_VOL" -gt 0 ] && [ "$STORED_VOL" -lt 99 ]; then
                # Re-apply stored volume to initialize WirePlumber's mixer node.
                # After this, wpctl get-volume correctly tracks changes.
                ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ "''${STORED_VOL}%"
                VOLUME="$STORED_VOL"
              fi
            fi
          fi
        fi
      fi
    fi

    DESC=$(${pkgs.pulseaudio}/bin/pactl list sinks | ${pkgs.gawk}/bin/awk -v sink="$SINK" '
      /^\s*Name:/ { found = ($2 == sink) }
      /^\s*Description:/ && found {
        sub(/^\s*Description:\s*/, "")
        print; exit
      }
    ')

    if   [ "$VOLUME" -eq 0 ]; then ICON="󰸈"; CLASS="muted"
    elif [ "$VOLUME" -le 33 ]; then ICON="󰕿"; CLASS="default"
    elif [ "$VOLUME" -le 66 ]; then ICON="󰖀"; CLASS="default"
    else ICON="󰕾"; CLASS="default"
    fi

    case "$DESC" in
      ${audioMappingCases}
      *) ;;
    esac

    if [ "$MUTED" -gt 0 ]; then
      TEXT="󰸈 MUTE"
      CLASS="muted"
    else
      TEXT="$ICON $VOLUME%"
    fi

    TOOLTIP="Sink: $SINK\nDesc: $DESC\nVol: $VOLUME%"
    printf '{"text":"%s","class":"%s","tooltip":"%s"}' "$TEXT" "$CLASS" "$TOOLTIP"
  '';

  vpnStatusScript = pkgs.writeShellScript "waybar-vpn-status" ''
    if systemctl is-active --quiet wg-quick-${vpnInterface}.service; then
      printf '{"text":"VPN ON","class":"active","tooltip":"WireGuard active — click to disconnect"}'
    else
      printf '{"text":"VPN OFF","class":"inactive","tooltip":"WireGuard inactive — click to connect"}'
    fi
  '';

  vpnToggleScript = pkgs.writeShellScript "waybar-vpn-toggle" ''
    if systemctl is-active --quiet wg-quick-${vpnInterface}.service; then
      pkexec systemctl stop wg-quick-${vpnInterface}.service
    else
      pkexec systemctl start wg-quick-${vpnInterface}.service
    fi
    pkill -RTMIN+9 waybar
  '';

  gammastepStatusScript = pkgs.writeShellScript "gammastep-waybar-status" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"

    [ ! -f "$STATE_FILE" ] && echo "2500:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"
    [ "$MODE" = "enabled" ] && MODE="auto"

    HOUR=$(date +%-H)
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then IS_DAY=1; else IS_DAY=0; fi

    temp_class() {
      T=$1
      if   [ "$T" -ge 5501 ]; then echo "temp-cool"
      elif [ "$T" -ge 4501 ]; then echo "temp-neutral"
      elif [ "$T" -ge 3501 ]; then echo "temp-amber"
      elif [ "$T" -ge 2001 ]; then echo "temp-warm"
      else                         echo "temp-hot"
      fi
    }

    if [ "$MODE" = "disabled" ]; then
      TEXT="OFF"
      CLASS="inactive"
      TOOLTIP="Night light off (''${TEMP}K preset) — click to enable"
    elif [ "$MODE" = "manual" ]; then
      TEXT="''${TEMP}K"
      CLASS="manual"
      TOOLTIP="Manual override: ''${TEMP}K — scroll to adjust — click to disable — right-click for auto"
    elif [ "$IS_DAY" = "1" ]; then
      TEXT="''${TEMP}K"
      CLASS="temp-day"
      TOOLTIP="Auto day (6500K active) — night preset: ''${TEMP}K — scroll to adjust — right-click for manual override"
    else
      TEXT="''${TEMP}K"
      CLASS="$(temp_class ''${TEMP})"
      TOOLTIP="Auto night: ''${TEMP}K — scroll to adjust — click to disable — right-click for manual"
    fi

    printf '{"text":"%s","class":"%s","tooltip":"%s"}' "$TEXT" "$CLASS" "$TOOLTIP"
  '';

  gammastepAdjustScript = pkgs.writeShellScript "gammastep-waybar-adjust" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    [ ! -f "$STATE_FILE" ] && echo "2500:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"
    [ "$MODE" = "enabled" ] && MODE="auto"

    STEP=250
    if [ "''${1:-up}" = "up" ]; then
      TEMP=$((TEMP + STEP))
      [ "$TEMP" -gt 6500 ] && TEMP=6500
    else
      TEMP=$((TEMP - STEP))
      [ "$TEMP" -lt 1000 ] && TEMP=1000
    fi

    echo "''${TEMP}:''${MODE}" > "$STATE_FILE"

    # Kill any in-progress gradual transition
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    HOUR=$(date +%-H)
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then IS_DAY=1; else IS_DAY=0; fi

    # Apply immediately in manual mode, or in auto mode during nighttime.
    # In auto daytime, just save the preset — display stays at dayTemp.
    if [ "$MODE" = "manual" ] || { [ "$MODE" = "auto" ] && [ "$IS_DAY" = "0" ]; }; then
      pkill -x hyprsunset 2>/dev/null || true
      sleep 0.2
      ${pkgs.hyprsunset}/bin/hyprsunset -t "''${TEMP}" &
      echo "''${TEMP}" > "$ACTIVE_FILE"
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  # Left-click: toggle disabled ↔ auto
  gammastepToggleScript = pkgs.writeShellScript "gammastep-waybar-toggle" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    [ ! -f "$STATE_FILE" ] && echo "2500:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"
    [ "$MODE" = "enabled" ] && MODE="auto"

    # Kill any in-progress transition
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    HOUR=$(date +%-H)
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then IS_DAY=1; else IS_DAY=0; fi

    if [ "$MODE" = "disabled" ]; then
      # Enable in auto mode, apply correct time-of-day temp immediately
      echo "''${TEMP}:auto" > "$STATE_FILE"
      pkill -x hyprsunset 2>/dev/null || true
      sleep 0.2
      if [ "$IS_DAY" = "1" ]; then
        ${pkgs.hyprsunset}/bin/hyprsunset -t ${toString customConfig.homeManager.services.hyprsunset.dayTemp} &
        echo "${toString customConfig.homeManager.services.hyprsunset.dayTemp}" > "$ACTIVE_FILE"
      else
        ${pkgs.hyprsunset}/bin/hyprsunset -t "''${TEMP}" &
        echo "''${TEMP}" > "$ACTIVE_FILE"
      fi
    else
      # Disable — kill hyprsunset, Hyprland resets CTM to identity
      echo "''${TEMP}:disabled" > "$STATE_FILE"
      pkill -x hyprsunset 2>/dev/null || true
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  # Right-click: toggle auto ↔ manual
  gammastepModeScript = pkgs.writeShellScript "gammastep-waybar-mode" ''
    STATE_FILE="$HOME/.cache/hyprsunset-state"
    ACTIVE_FILE="$HOME/.cache/hyprsunset-active-temp"
    PID_FILE="$HOME/.cache/hyprsunset-transition.pid"

    [ ! -f "$STATE_FILE" ] && echo "2500:auto" > "$STATE_FILE"

    STATE=$(cat "$STATE_FILE")
    TEMP="''${STATE%%:*}"
    MODE="''${STATE##*:}"
    [ "$MODE" = "enabled" ] && MODE="auto"

    [ "$MODE" = "disabled" ] && exit 0  # no-op when disabled

    # Kill any in-progress transition
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi

    HOUR=$(date +%-H)
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then IS_DAY=1; else IS_DAY=0; fi

    if [ "$MODE" = "auto" ]; then
      # Switch to manual — if daytime, snap to night preset so night light turns on NOW
      echo "''${TEMP}:manual" > "$STATE_FILE"
      if [ "$IS_DAY" = "1" ]; then
        pkill -x hyprsunset 2>/dev/null || true
        sleep 0.2
        ${pkgs.hyprsunset}/bin/hyprsunset -t "''${TEMP}" &
        echo "''${TEMP}" > "$ACTIVE_FILE"
      fi
      # If nighttime: already at TEMP, no change needed
    else
      # Switch to auto — snap to correct time-of-day temp immediately
      echo "''${TEMP}:auto" > "$STATE_FILE"
      pkill -x hyprsunset 2>/dev/null || true
      sleep 0.2
      if [ "$IS_DAY" = "1" ]; then
        ${pkgs.hyprsunset}/bin/hyprsunset -t ${toString customConfig.homeManager.services.hyprsunset.dayTemp} &
        echo "${toString customConfig.homeManager.services.hyprsunset.dayTemp}" > "$ACTIVE_FILE"
      else
        ${pkgs.hyprsunset}/bin/hyprsunset -t "''${TEMP}" &
        echo "''${TEMP}" > "$ACTIVE_FILE"
      fi
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  specialWorkspaceScript = pkgs.writeShellScript "waybar-special-workspace" ''
    WINDOWS=$(${pkgs.hyprland}/bin/hyprctl workspaces -j 2>/dev/null \
      | ${pkgs.jq}/bin/jq '[.[] | select(.name == "special:ckb")] | .[0].windows // 0')
    if [ "''${WINDOWS:-0}" -gt 0 ]; then
      printf '{"text":"UTIL","class":"occupied","tooltip":"Special workspace: %s window(s) — SUPER+` to toggle"}' "$WINDOWS"
    else
      printf '{"text":"UTIL","class":"empty","tooltip":"Special workspace empty — SUPER+` to open"}'
    fi
  '';

  # Generate custom module configurations for launcher buttons
  generateLauncherModules = apps:
    lib.listToAttrs (lib.imap0 (idx: app: {
      name = "custom/launcher${toString idx}";
      value = {
        format = app.label;
        on-click = app.command;
        tooltip = lib.mkIf (app.tooltip != null) true;
        tooltip-format = if app.tooltip != null then app.tooltip else app.label;
      };
    }) apps);

in
{
  imports = [
    # Relative path from de-wm-components/waybar/ to scripts/
    ../../scripts/audio-switcher.nix    # Audio sink switcher script
    ../../scripts/hyprsunset-control.nix # Hyprsunset control scripts
  ];

  config = lib.mkIf isHyprlandHost {
    programs.waybar = {
      enable = true;
      systemd.enable = false; # Ensures Waybar must be launched implicitly by the wayland compositor such as Hyprland

      settings = lib.mkMerge [
        # Main bar configuration (always present)
        {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30; # Base height, can be overridden by theme if needed
            spacing = 4; # Base spacing, can be overridden
            # Note: omitting 'output' field means show on all monitors

            modules-left = [
              "hyprland/workspaces"
              "hyprland/mode"
            ] ++ lib.optionals hasCkbNext [ "custom/special-workspace" "custom/ckb-color" ];
            modules-center = [
              "hyprland/window"
            ];
            modules-right = lib.optionals hasScreenBacklight [ "backlight" ]
              ++ lib.optionals hasKbdBacklight [ "custom/kbd-brightness" ]
              ++ lib.optionals hasVpnClient [ "custom/vpn" ]
              ++ lib.optionals hasBattery [ "battery" ]
              ++ lib.optionals hasWeather [ "custom/weather" ]
              ++ lib.optionals hasHyprsunset [ "custom/hyprsunset" ]
              ++ [
              "network"
              "custom/audio-sink"
              "cpu"
              "memory"
              "clock"
              "tray"
              "custom/power"
            ];

          # === Functional Module Settings ===
          "hyprland/window" = {
            max-length = 50; # Functional constraint
            separate-outputs = true;
          };

          clock = {
            # Basic tooltip, specific clock format string is in rice
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };

          cpu = {
            tooltip = true; # Enable tooltip, specific format is in rice
          };

          memory = {
            # Specific format is in rice
          };

          backlight = lib.mkIf hasScreenBacklight {
            format = "{percent}%";  # Theme will override with cockpit label
            on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +5%";
            on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
            smooth-scrolling-threshold = 1;
          };

          "custom/kbd-brightness" = lib.mkIf hasKbdBacklight {
            exec = "${pkgs.brightnessctl}/bin/brightnessctl -d asus::kbd_backlight get";
            interval = 3;
            signal = 8;
            format = "{}";  # Theme will override with cockpit label
            on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl -d asus::kbd_backlight set +1 && pkill -RTMIN+8 waybar";
            on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl -d asus::kbd_backlight set 1- && pkill -RTMIN+8 waybar";
          };

          "custom/vpn" = lib.mkIf hasVpnClient {
            exec = "${vpnStatusScript}";
            return-type = "json";
            interval = 5;
            signal = 9;
            on-click = "${vpnToggleScript}";
          };

          "custom/hyprsunset" = lib.mkIf hasHyprsunset {
            exec = "${gammastepStatusScript}";
            return-type = "json";
            interval = 60;
            signal = 12;  # pkill -RTMIN+12 waybar forces an immediate refresh
            on-click = "${gammastepToggleScript}";
            on-click-right = "${gammastepModeScript}";
            on-scroll-up = "${gammastepAdjustScript} up";
            on-scroll-down = "${gammastepAdjustScript} down";
            smooth-scrolling-threshold = 1;
          };

          battery = lib.mkIf hasBattery {
            interval = 30;
            states = {
              warning = 20;
              critical = 10;
            };
            format = lib.mkDefault "{capacity}%";
            format-charging = lib.mkDefault "CHG {capacity}%";
            format-plugged = lib.mkDefault "PLG {capacity}%";
            format-full = lib.mkDefault "FULL";
            tooltip = true;
            tooltip-format = "{timeTo} — {capacity}% ({power:.1f}W)";
          };

          network = {
            # Functional formats without icons; rice can override with icons
            format-wifi = "{essid} ({signalStrength}%)";
            format-ethernet = "{ifname}: {ipaddr}/{cidr}";
            format-disconnected = "Disconnected"; # Simple status
            tooltip-format = "{ifname} via {gwaddr}"; # Functional tooltip
            on-click = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu"; # Functional action
            on-click-right = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          };

          "custom/audio-sink" = {
            exec = "${audioStatusScript}";
            return-type = "json";
            interval = 2;
            signal = 11;  # pkill -RTMIN+11 waybar forces an immediate refresh
            on-click = "switch-audio-sink";
            on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
            on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 && pkill -RTMIN+11 waybar";
            on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && pkill -RTMIN+11 waybar";
          };

          tray = {
            spacing = 10; # Functional spacing for tray items
            # icon-size is ricing
          };

          "custom/weather" = lib.mkIf hasWeather {
            exec = "${weatherScript}";
            return-type = "json";
            interval = 300; # Refresh every 5 minutes
            signal = 10;
            format = lib.mkDefault "{}";
          };

          "custom/power" = {
            format = lib.mkDefault "⏻";  # Unicode power symbol, theme can override
            tooltip = true;
            tooltip-format = lib.mkDefault "Power Menu";
            on-click = "${pkgs.wlogout}/bin/wlogout";
          };

          "hyprland/mode" = {
            # Potentially no specific functional config needed if defaults are fine
            # The rice file can add styling or format if required
          };

          "custom/special-workspace" = lib.mkIf hasCkbNext {
            exec = "${specialWorkspaceScript}";
            return-type = "json";
            interval = 2;
            signal = 13;  # pkill -RTMIN+13 waybar forces an immediate refresh
          };

          "custom/ckb-color" = lib.mkIf hasCkbNext {
            exec = "${ckbScripts.colorStatusScript}";
            return-type = "json";
            interval = 30;  # infrequent poll; cycle/brightness scripts signal on change
            signal = 14;    # pkill -RTMIN+14 waybar forces an immediate refresh
          };

          "hyprland/workspaces" = {
            # Most settings like format-icons are pure rice.
            # persistent_workspaces could be functional if you always want a fixed number.
            # persistent_workspaces = { "*": 5 }; # Example: uncomment if desired functionally
          };
        }; # End mainBar
        }

        # Launcher bar configuration (conditional)
        (lib.mkIf launcherEnabled {
          launcherBar = {
            layer = "bottom";
            position = "bottom";
            height = 48; # Base height for launcher
            spacing = 8; # Spacing between launcher items

            modules-left = [];
            modules-center = map (idx: "custom/launcher${toString idx}") (lib.lists.range 0 ((lib.length pinnedApps) - 1));
            modules-right = [];
          } // (generateLauncherModules pinnedApps);
        })
      ]; # End settings mkMerge
    }; # End programs.waybar

    home.packages = with pkgs; [
      # Dependencies for functional aspects of Waybar modules
      networkmanager_dmenu  # For network module on-click
      networkmanagerapplet  # For network module on-click-right (nm-connection-editor)
      pavucontrol           # For pulseaudio module on-click-right
      brightnessctl        # For backlight and kbd-brightness modules
      curl                 # For weather module HTTP requests
      jq                   # For weather module JSON parsing
      # audio-switcher script dependencies should be handled by its own module if it has any non-pkgs ones
    ];

    systemd.user.services.waybar = {
      # These options are added to the [Unit] section of the systemd service file.
      UnitConfig = {
        # This tells systemd: "Only start this service if the
        # XDG_CURRENT_DESKTOP environment variable is present and set to Hyprland".
        # This check happens at login time, not at build time.
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      };
    };
  };
}