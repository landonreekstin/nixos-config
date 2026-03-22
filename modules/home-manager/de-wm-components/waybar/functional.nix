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

  vpnInterface = customConfig.services.wireguard.client.interfaceName;

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
    ../../scripts/audio-switcher.nix # Audio sink switcher script
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
            ];
            modules-center = [
              "hyprland/window"
            ];
            modules-right = lib.optionals hasScreenBacklight [ "backlight" ]
              ++ lib.optionals hasKbdBacklight [ "custom/kbd-brightness" ]
              ++ lib.optionals hasVpnClient [ "custom/vpn" ]
              ++ lib.optionals hasBattery [ "battery" ]
              ++ [
              "network"
              "pulseaudio#sink_switcher"
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
          };

          "pulseaudio#sink_switcher" = {
            # Functional formats without icons; rice can override
            format = "{volume}%";
            format-bluetooth = "{volume}%"; # Base format for bluetooth state
            format-muted = "Muted";          # Base format for muted state
            scroll-step = 5;                 # Functional behavior
            on-click = "switch-audio-sink";  # Functional action from imported script
            on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol"; # Functional action
          };

          tray = {
            spacing = 10; # Functional spacing for tray items
            # icon-size is ricing
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
      networkmanager_dmenu # For network module on-click
      pavucontrol          # For pulseaudio module on-click-right
      brightnessctl        # For backlight and kbd-brightness modules
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