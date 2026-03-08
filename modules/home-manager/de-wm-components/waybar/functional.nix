# ~/nixos-config/modules/home-manager/de-wm-components/waybar/functional.nix
{ config, pkgs, lib, customConfig, ... }:

let

  isHyprlandHost = lib.elem "hyprland" customConfig.desktop.environments;
  launcherEnabled = customConfig.desktop.hyprland.launcher.enable;
  pinnedApps = customConfig.desktop.hyprland.launcher.pinnedApps;

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
            modules-right = [
              "network"
              "pulseaudio#sink_switcher"
              "cpu"
              "memory"
              "clock"
              "tray"
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