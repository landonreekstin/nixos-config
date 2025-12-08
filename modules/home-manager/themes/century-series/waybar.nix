# ~/nixos-config/modules/home-manager/themes/century-series/waybar.nix
{ config, pkgs, lib, customConfig, centuryColors ? {}, centuryConfig ? {}, ... }:

with lib;

let
  c = centuryColors;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.waybar = {
      enable = true;

      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 36;
          spacing = 0;

          # Left side - Primary flight instruments
          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];

          # Center - Navigation data
          modules-center = [
            "clock"
          ];

          # Right side - Systems monitoring (like engine instruments)
          modules-right = [
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "temperature"
            "battery"
            "tray"
          ];

          # Workspace switcher - like mode selector switches
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
            persistent-workspaces = {
              "*" = 5;
            };
            on-click = "activate";
          };

          # Active window - like MFD page indicator
          "hyprland/window" = {
            format = "│ {}";
            max-length = 50;
            separate-outputs = true;
          };

          # Clock - Mission timer style
          clock = {
            interval = 1;
            format = "{:%H:%M:%S}";
            format-alt = "{:%Y-%m-%d %H:%M:%S %Z}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "month";
              format = {
                today = "<span color='${c.accent-amber}'><b>{}</b></span>";
              };
            };
          };

          # CPU - Engine RPM style gauge
          cpu = {
            interval = 2;
            format = "PWR {usage}%";
            format-alt = "PWR {avg_frequency}GHz";
            tooltip = true;
            states = {
              warning = 70;
              critical = 90;
            };
          };

          # Memory - Fuel quantity style
          memory = {
            interval = 5;
            format = "MEM {}%";
            format-alt = "MEM {used:0.1f}G/{total:0.1f}G";
            tooltip-format = "RAM: {used:0.1f}G / {total:0.1f}G\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G";
            states = {
              warning = 70;
              critical = 90;
            };
          };

          # Temperature - EGT (Exhaust Gas Temperature) style
          temperature = {
            hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
            critical-threshold = 80;
            interval = 2;
            format = "TMP {temperatureC}°C";
            format-critical = "⚠ {temperatureC}°C";
            tooltip = true;
          };

          # Network - IFF transponder style
          network = {
            interval = 5;
            format-wifi = "LINK {signalStrength}%";
            format-ethernet = "LINK UP";
            format-disconnected = "LINK DOWN";
            tooltip-format = "{ifname}: {ipaddr}/{cidr}\nUp: {bandwidthUpBits} Down: {bandwidthDownBits}";
            format-alt = "{essid}";
          };

          # Audio - Intercom volume
          pulseaudio = {
            format = "VOL {volume}%";
            format-muted = "VOL MUTE";
            format-icons = {
              default = ["" "" ""];
            };
            on-click = "pavucontrol";
            tooltip-format = "{desc}\n{volume}%";
          };

          # Battery - Electrical system
          battery = {
            interval = 10;
            states = {
              warning = 30;
              critical = 15;
            };
            format = "BAT {capacity}%";
            format-charging = "CHG {capacity}%";
            format-plugged = "EXT PWR";
            format-full = "BAT FULL";
            tooltip-format = "{timeTo}\n{capacity}% - {power}W";
          };

          # System tray
          tray = {
            icon-size = 18;
            spacing = 8;
          };
        };
      };

      # CSS Styling - Instrument panel aesthetic
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

        /* Workspace buttons - Mode selector switches */
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

        #workspaces button.urgent {
          background-color: ${c.warning-red};
          color: ${c.text-primary};
          animation: blink 1s ease-in-out infinite;
        }

        /* Window title - MFD readout */
        #window {
          margin: 0 12px;
          padding: 0 8px;
          color: ${c.accent-green};
          font-style: italic;
        }

        /* Clock - Mission timer display */
        #clock {
          padding: 0 16px;
          background-color: ${c.bg-tertiary};
          color: ${c.accent-amber};
          border-left: 1px solid ${c.border-primary};
          border-right: 1px solid ${c.border-primary};
          font-family: "JetBrains Mono", monospace;
          font-weight: 700;
          letter-spacing: 1px;
        }

        /* Module base style - Instrument gauge */
        #cpu,
        #memory,
        #temperature,
        #network,
        #pulseaudio,
        #battery {
          padding: 0 14px;
          margin: 4px 2px;
          background-color: ${c.bg-secondary};
          color: ${c.text-primary};
          border: 1px solid ${c.border-primary};
        }

        /* CPU - Amber power gauge */
        #cpu {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        #cpu.warning {
          color: ${c.caution-yellow};
          border-color: ${c.caution-yellow};
        }

        #cpu.critical {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          animation: blink 1s ease-in-out infinite;
        }

        /* Memory - Green fuel gauge */
        #memory {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
        }

        #memory.warning {
          color: ${c.caution-yellow};
          border-color: ${c.caution-yellow};
        }

        #memory.critical {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          animation: blink 1s ease-in-out infinite;
        }

        /* Temperature - EGT readout */
        #temperature {
          color: ${c.info-blue};
          border-color: ${c.info-blue};
        }

        #temperature.critical {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          animation: blink 1s ease-in-out infinite;
        }

        /* Network - Data link indicator */
        #network {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
        }

        #network.disconnected {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
        }

        /* Audio - Volume indicator */
        #pulseaudio {
          color: ${c.accent-amber};
          border-color: ${c.accent-amber-dim};
        }

        #pulseaudio.muted {
          color: ${c.text-tertiary};
          border-color: ${c.border-primary};
        }

        /* Battery - Electrical system */
        #battery {
          color: ${c.accent-green};
          border-color: ${c.accent-green-dim};
        }

        #battery.charging {
          color: ${c.info-blue};
          border-color: ${c.info-blue};
        }

        #battery.warning {
          color: ${c.caution-yellow};
          border-color: ${c.caution-yellow};
        }

        #battery.critical {
          color: ${c.warning-red};
          border-color: ${c.warning-red};
          animation: blink 1s ease-in-out infinite;
        }

        /* System tray */
        #tray {
          padding: 0 8px;
          margin: 4px 4px 4px 2px;
        }

        #tray > .passive {
          opacity: 0.7;
        }

        #tray > .needs-attention {
          color: ${c.warning-red};
          animation: blink 1s ease-in-out infinite;
        }

        /* Warning blink animation - Master caution light */
        @keyframes blink {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.3; }
        }

        /* Tooltip styling */
        tooltip {
          background-color: ${c.bg-primary};
          border: 2px solid ${c.border-primary};
          border-radius: 0;
          color: ${c.text-primary};
        }

        tooltip label {
          color: ${c.text-primary};
        }
      '';
    };
  };
}
