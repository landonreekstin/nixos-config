# ~/nixos-config/modules/home-manager/rice/century-series/waybar.nix
{ config, pkgs, lib, ... }:

let
  # Re-define palette here or import from a central location later
  palette = {
    base_silver = "#DADADA"; base_grey = "#B0B0B0"; base_charcoal = "#404040";
    base_offwhite = "#F5F5F5"; base_nearblack = "#2A2A2A"; accent_cyan = "#40E0D0";
    accent_cyan_light = "#7FFFD4"; accent_amber = "#FFBF00"; accent_green = "#32CD32";
    accent_blue = "#4682B4"; accent_blue_light = "#87CEEB"; accent_red_neg = "#CD5C5C";
  };
in
{
  # Enable Waybar program management via Home Manager
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    # Basic settings (JSON format)
    # Defines modules and their placement
    # Ref: https://github.com/Alexays/Waybar/wiki/Configuration
    settings = {
      mainBar = { # Use an object if only one bar definition needed
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        # Modules displayed on the left
        modules-left = [
          "hyprland/workspaces"
          "hyprland/mode"
        ];

        # Modules displayed in the center
        modules-center = [
          "hyprland/window"
        ];

        # Modules displayed on the right
        modules-right = [
          "network"
          "pulseaudio"
          "cpu"
          "memory"
          "clock"
          "tray"
          # "battery" # Add if laptop
        ];

        # Module-specific configuration
        "hyprland/workspaces" = {
          format = "{icon}"; # Use icons for workspaces later
          format-icons = {
            "1" = ""; # Example Nerd Font icons (replace later)
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            "default" = "";
            "urgent" = "";
            "persistent" = ""; # Placeholder
          };
          # persistent_workspaces = { "*": 5 }; # Show 5 workspaces always
        };
        "hyprland/window" = {
          max-length = 50;
          separate-outputs = true;
        };
        clock = {
          format = " {:%a %b %d %H:%M}"; # Example format
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        cpu = {
          format = " {usage}%";
          tooltip = true;
        };
        memory = {
          format = " {}%";
        };
        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ifname}: {ipaddr}/{cidr}";
          format-disconnected = "⚠ Disconnected";
          tooltip-format = "{ifname} via {gwaddr}";
          on-click = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu"; # Example action
        };
        pulseaudio = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-muted = " Muted";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" ""];
          };
          scroll-step = 5;
        };
        tray = {
          icon-size = 18;
          spacing = 10;
        };
      }; # End mainBar
    }; # End settings

    # Basic styling (CSS format)
    # Ref: https://github.com/Alexays/Waybar/wiki/Styling
    style = ''
      * {
          /* `otf-font-awesome` is required to be installed for icons */
          font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free';
          font-size: 13px;
          border: none;
          border-radius: 0;
          min-height: 0;
      }

      window#waybar {
          background-color: rgba(64, 64, 64, 0.8); /* Semi-transparent Charcoal */
          color: ${palette.base_offwhite}; /* Off-White text */
          transition-property: background-color;
          transition-duration: .5s;
      }

      #workspaces button {
          padding: 0 5px;
          background-color: transparent;
          color: ${palette.base_grey}; /* Inactive workspace color */
      }

      #workspaces button:hover {
          background: rgba(0, 0, 0, 0.2);
      }

      #workspaces button.focused {
          color: ${palette.accent_cyan}; /* Active workspace color */
          /* Add subtle background or border later */
      }

      #workspaces button.urgent {
          color: ${palette.accent_red_neg}; /* Urgent workspace color */
      }

      #mode {
          padding: 0 10px;
          background-color: ${palette.accent_amber};
          color: ${palette.base_nearblack};
          border-bottom: 3px solid ${palette.base_offwhite};
      }

      /* Style other modules based on palette */
      #clock,
      #cpu,
      #memory,
      #tray,
      #pulseaudio,
      #network,
      #hyprland-window {
          padding: 0 10px;
          margin: 0 4px;
          color: ${palette.base_offwhite};
      }

      #pulseaudio.muted {
          color: ${palette.accent_amber};
      }

      #network.disconnected {
           color: ${palette.accent_red_neg};
      }

      /* Add more specific styles later */
    ''; # End style

  }; # End programs.waybar

  # Add Waybar dependencies
  home.packages = with pkgs; [
    font-awesome # For icons used in default waybar config/style
    # Other dependencies for modules if needed:
    # playerctl # For MPRIS module
    networkmanagerapplet # If using NM tray icon
    networkmanager_dmenu # For network module on-click
  ];
}