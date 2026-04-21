# ~/nixos-config/modules/home-manager/themes/century-series/waybar.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # Check if launcher is enabled
  launcherEnabled = customConfig.desktop.hyprland.launcher.enable;
  hasScreenBacklight = customConfig.hardware.display.backlight.enable;
  hasKbdBacklight = customConfig.hardware.kbdBacklight.enable;
  hasBattery = customConfig.hardware.battery.enable;

in {
  config = mkIf centurySeriesThemeCondition {
    programs.waybar = {
      # Settings here will be merged with functional.nix
      settings = {
        mainBar = {
          # Century Series theme styling overrides
          height = mkForce 36;  # Slightly taller for cockpit instrument feel
          spacing = mkForce 0;   # Tight spacing like instrument panel

          # Tactical workspace labels - like mode selector switches  
          "hyprland/workspaces" = {
            format = "{icon}";
            format-icons = {
              "1" = "NAV";   # Navigation
              "2" = "COM";   # Communications (browser)
              "3" = "SYS";   # Systems (files)
              "4" = "WPN";   # Weapons (gaming)
              "5" = "ECM";   # ECM (misc)
              "6" = "AUX1";
              "7" = "AUX2";
              "8" = "AUX3";
              "9" = "AUX4";
              "10" = "AUX5";
            };
          };

          # Mission timer style clock
          clock = {
            interval = 1;
            format = "{:%H:%M:%S}";
            format-alt = "{:%Y-%m-%d %H:%M:%S %Z}";
            tooltip-format = mkForce "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "month";
              format = {
                today = "<span color='${c.accent-amber}'><b>{}</b></span>";
              };
            };
          };

          # Override specific module styling to match cockpit theme
          cpu = {
            format = "PWR {usage}%";  # Engine power style
          };

          memory = {
            format = "MEM {}%";       # Fuel quantity style  
          };

          temperature = {
            format = "TMP {temperatureC}°C";  # EGT style
          };

          network = {
            format-wifi = mkForce "LINK {signalStrength}%";
            format-ethernet = mkForce "LINK UP";
            format-disconnected = mkForce "LINK DOWN";
            tooltip-format = mkForce "NET: {ifname} via {gwaddr}";
          };

          backlight = mkIf hasScreenBacklight {
            format = mkForce "SCR {percent}%";
            tooltip-format = "Screen brightness: {percent}%";
          };

          "custom/kbd-brightness" = mkIf hasKbdBacklight {
            format = mkForce "KBD {}";
            tooltip = true;
            tooltip-format = "Keyboard backlight: {}";
          };

          # custom/audio-sink: format is returned by the script, no waybar format override needed
          # (icon and volume are already embedded in the script's JSON "text" field)

          battery = mkIf hasBattery {
            format = mkForce "BAT {capacity}%";
            format-charging = mkForce "CHG {capacity}%";
            format-plugged = mkForce "EXT PWR";
            format-full = mkForce "BAT FULL";
            states = mkForce {
              critical = 10;   # red + blink
              low      = 25;   # orange
              medium   = 50;   # yellow
              high     = 75;   # yellow-green
              # >75%: default green (no state class)
            };
          };

          # Night light - Cockpit display thermal control
          "custom/gammastep" = {
            format = mkForce "NL {}";  # Night Light
          };

          # Power button - Engine control
          "custom/power" = {
            format = mkForce "PWR";  # Aviation style label
            tooltip-format = mkForce "ENG PWR MENU";  # Aviation terminology
          };
        };
      } // lib.optionalAttrs launcherEnabled {
        # Launcher bar - Cockpit control panel styling
        launcherBar = {
          height = mkForce 48;   # Taller for prominent control switches
          spacing = mkForce 8;   # Spacing between launcher buttons
        };
      };

      # CSS Styling - Century Series Cockpit Theme
      style = ''
        * {
          font-family: "JetBrains Mono", "Fira Code", monospace;
          font-size: 13px;
          font-weight: 600;
          min-height: 0;
          letter-spacing: 0.5px;
        }

        /* Main bar - Instrument panel background */
        window#waybar {
          background-color: ${c.bg-primary};
          border-bottom: 2px solid ${c.border-primary};
          color: ${c.text-primary};
        }

        /* Workspace buttons - Tactical mode selectors */
        #workspaces {
          margin: 0;
          padding: 0;
        }

        #workspaces button {
          padding: 0 12px;
          margin: 4px 2px;
          background-color: ${c.bg-secondary};
          color: ${c.text-secondary};
          border: 1px solid ${c.border-primary};
          border-radius: 0;
          transition: all 0.2s ease;
        }

        #workspaces button:hover {
          background-color: ${c.border-active};
          color: ${c.text-primary};
          border-color: ${c.accent-amber-dim};
        }

        #workspaces button.active {
          background-color: ${c.accent-amber};
          color: ${c.bg-primary};
          border-color: ${c.accent-amber-glow};
          box-shadow: 0 0 8px ${c.accent-amber}66;
        }

        /* Clock - Mission chronometer */
        #clock {
          color: ${c.accent-amber};
          font-weight: bold;
          padding: 0 12px;
          background-color: ${c.bg-tertiary};
          border: 1px solid ${c.accent-amber-dim};
        }

        /* Module base styling - Instrument readouts */
        #cpu, #memory, #temperature, #network, #battery, #custom-audio-sink,
        #backlight, #custom-kbd-brightness, #custom-vpn {
          padding: 0 8px;
          margin: 2px;
          background-color: ${c.bg-tertiary};
          border: 1px solid ${c.border-secondary};
          color: ${c.text-primary};
          font-family: "JetBrains Mono", monospace;
        }

        /* Screen brightness - Illumination readout */
        #backlight {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        /* Keyboard backlight - Cockpit lighting control */
        #custom-kbd-brightness {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
        }

        /* Battery - Power cell readout (gradient: green → yellow-green → yellow → orange → red) */
        #battery {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
        }

        #battery.high {
          color: ${c.caution-yellow-green};
          border-color: ${c.caution-yellow-green};
        }

        #battery.medium {
          color: ${c.caution-yellow};
          border-color: ${c.caution-yellow};
        }

        #battery.low {
          color: ${c.warning-orange};
          border-color: ${c.warning-orange};
        }

        #battery.charging {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        #battery.plugged {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        #battery.critical {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          animation-name: blink;
          animation-duration: 1s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
        }

        @keyframes blink {
          to { opacity: 0.5; }
        }

        /* VPN - Secure comms indicator */
        #custom-vpn {
          font-weight: bold;
          letter-spacing: 1px;
          border-color: ${c.border-primary};
          color: ${c.text-secondary};
          transition: all 0.3s ease;
        }

        #custom-vpn.active {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
          box-shadow: 0 0 6px ${c.accent-green}44;
        }

        #custom-vpn.inactive {
          color: ${c.text-secondary};
          border-color: ${c.border-primary};
        }

        #custom-vpn:hover {
          background-color: ${c.bg-secondary};
          color: ${c.accent-green};
          border-color: ${c.accent-green};
        }

        /* Audio sink indicator - device type states */
        #custom-audio-sink.speakers {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        #custom-audio-sink.headphones {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
          box-shadow: 0 0 6px ${c.accent-green}44;
        }

        #custom-audio-sink.muted {
          color: ${c.text-tertiary};
          border-color: ${c.border-primary};
          opacity: 0.6;
        }

        /* System tray */
        #tray {
          padding: 0 8px;
          background-color: ${c.bg-secondary};
        }

        /* Power button - Engine control switch */
        #custom-power {
          padding: 0 12px;
          margin: 2px 4px;
          background-color: ${c.bg-secondary};
          border: 2px solid ${c.warning-red};
          color: ${c.warning-red};
          font-weight: bold;
          transition: all 0.2s ease;
        }

        #custom-power:hover {
          background-color: ${c.warning-red};
          color: ${c.bg-primary};
          box-shadow: 0 0 8px ${c.warning-red}80;
        }

        /* Weather — Atmospheric condition indicator light */
        #custom-weather {
          padding: 0 10px;
          margin: 2px;
          background-color: ${c.bg-tertiary};
          border: 1px solid ${c.border-secondary};
          color: ${c.text-primary};
          font-family: "JetBrains Mono", monospace;
          letter-spacing: 1px;
        }

        #custom-weather.clear {
          color: ${c.caution-yellow};
          border-color: ${c.caution-yellow};
          text-shadow: 0 0 8px ${c.caution-yellow}cc;
        }

        #custom-weather.partly-cloudy {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
          text-shadow: 0 0 6px ${c.accent-amber}88;
        }

        #custom-weather.cloudy {
          color: ${c.text-secondary};
          border-color: ${c.border-secondary};
        }

        #custom-weather.fog {
          color: ${c.info-blue};
          border-color: ${c.info-blue};
          opacity: 0.75;
        }

        #custom-weather.rain {
          color: ${c.info-blue};
          border-color: ${c.info-blue};
          text-shadow: 0 0 6px ${c.info-blue}aa;
        }

        #custom-weather.snow {
          color: #b0d4ff;
          border-color: #b0d4ff;
          text-shadow: 0 0 8px #b0d4ffaa;
        }

        #custom-weather.storm {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          text-shadow: 0 0 8px ${c.warning-red}cc;
          animation-name: blink;
          animation-duration: 2s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
        }

        #custom-weather.error, #custom-weather.unknown {
          color: ${c.text-tertiary};
          border-color: ${c.border-primary};
          opacity: 0.5;
        }

        /* Night light - Display thermal control indicator */
        #custom-gammastep {
          padding: 0 8px;
          margin: 2px;
          background-color: ${c.bg-tertiary};
          border: 1px solid ${c.border-secondary};
          color: ${c.text-primary};
          font-family: "JetBrains Mono", monospace;
          transition: color 0.4s ease, border-color 0.4s ease, box-shadow 0.4s ease;
        }

        /* OFF - disabled, greyed out */
        #custom-gammastep.inactive {
          color: ${c.text-tertiary};
          border-color: ${c.border-primary};
          opacity: 0.45;
        }

        /* DAY - daytime auto mode, 6500K neutral, blue instrument light */
        #custom-gammastep.temp-day {
          color: ${c.info-blue};
          border-color: ${c.info-blue};
          text-shadow: 0 0 6px ${c.info-blue}88;
        }

        /* MANUAL - manual override, dashed amber border = "override engaged" */
        #custom-gammastep.manual {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber};
          border-style: dashed;
          text-shadow: 0 0 6px ${c.accent-amber}88;
          box-shadow: 0 0 4px ${c.accent-amber}44;
        }

        /* 5501–6500K - near daylight, warm white */
        #custom-gammastep.temp-cool {
          color: #ffe8a0;
          border-color: #ccba70;
        }

        /* 4501–5500K - amber-glow */
        #custom-gammastep.temp-neutral {
          color: ${c.caution-yellow};
          border-color: ${c.accent-amber-dim};
          text-shadow: 0 0 6px ${c.caution-yellow}88;
        }

        /* 3501–4500K - main amber */
        #custom-gammastep.temp-amber {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
          text-shadow: 0 0 6px ${c.accent-amber}88;
          box-shadow: 0 0 4px ${c.accent-amber}33;
        }

        /* 2001–3500K - orange */
        #custom-gammastep.temp-warm {
          color: ${c.warning-orange};
          border-color: ${c.warning-orange};
          text-shadow: 0 0 8px ${c.warning-orange}aa;
          box-shadow: 0 0 6px ${c.warning-orange}44;
        }

        /* 1000–2000K - red, very warm */
        #custom-gammastep.temp-hot {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          text-shadow: 0 0 10px ${c.warning-red}cc;
          box-shadow: 0 0 8px ${c.warning-red}55;
        }

        /* Tooltip styling - Info displays */
        tooltip {
          background-color: ${c.bg-primary};
          border: 2px solid ${c.border-primary};
          border-radius: 0;
          color: ${c.text-primary};
        }

        tooltip label {
          color: ${c.text-primary};
        }
      '' + lib.optionalString launcherEnabled ''

        /* ===== LAUNCHER BAR - COCKPIT CONTROL PANEL ===== */

        /* Launcher bar background - Control panel surface */
        window#waybar.launcherBar {
          background-color: ${c.bg-secondary};
          border-top: 3px solid ${c.border-primary};
          border-bottom: none;
          box-shadow: 0 -2px 10px ${c.bg-primary}cc;
        }

        /* Launcher buttons - Cockpit control switches */
        #custom-launcher0, #custom-launcher1, #custom-launcher2, #custom-launcher3,
        #custom-launcher4, #custom-launcher5, #custom-launcher6, #custom-launcher7,
        #custom-launcher8, #custom-launcher9 {
          padding: 8px 16px;
          margin: 4px 4px;
          background: linear-gradient(180deg, ${c.bg-tertiary} 0%, ${c.bg-secondary} 100%);
          color: ${c.text-primary};
          border: 2px solid ${c.border-primary};
          border-radius: 2px;
          font-size: 12px;
          font-weight: bold;
          letter-spacing: 1px;
          min-width: 70px;
          box-shadow:
            inset 0 1px 0 ${c.border-secondary}40,
            0 2px 4px ${c.bg-primary}80;
          transition: all 0.15s ease;
        }

        /* Launcher button hover - Illuminated switch */
        #custom-launcher0:hover, #custom-launcher1:hover, #custom-launcher2:hover, #custom-launcher3:hover,
        #custom-launcher4:hover, #custom-launcher5:hover, #custom-launcher6:hover, #custom-launcher7:hover,
        #custom-launcher8:hover, #custom-launcher9:hover {
          background: linear-gradient(180deg, ${c.accent-amber-dim} 0%, ${c.accent-amber} 100%);
          color: ${c.bg-primary};
          border-color: ${c.accent-amber-glow};
          box-shadow:
            inset 0 1px 0 ${c.accent-amber-glow}60,
            0 0 12px ${c.accent-amber}80,
            0 4px 6px ${c.bg-primary}80;
        }

        /* Launcher button active - Switch pressed */
        #custom-launcher0:active, #custom-launcher1:active, #custom-launcher2:active, #custom-launcher3:active,
        #custom-launcher4:active, #custom-launcher5:active, #custom-launcher6:active, #custom-launcher7:active,
        #custom-launcher8:active, #custom-launcher9:active {
          background: linear-gradient(180deg, ${c.accent-amber} 0%, ${c.accent-amber-dim} 100%);
          box-shadow:
            inset 0 2px 4px ${c.bg-primary}60,
            0 0 8px ${c.accent-amber}60;
        }
      '';
    };

    # networkmanager_dmenu config - use rofi (with Century Series styling) instead of dmenu
    xdg.configFile."networkmanager-dmenu/config.ini".text = ''
      [dmenu]
      dmenu_command = rofi -dmenu
      rofi_highlight = True
      list_saved = True
      wifi_chars = ▂▄▆█

      [editor]
      terminal = kitty
      gui_if_available = True
    '';
  };
}
