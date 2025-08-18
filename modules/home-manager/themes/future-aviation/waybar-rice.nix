# ~/nixos-config/modules/home-manager/themes/future-aviation/waybar-rice.nix
{ config, pkgs, lib, customConfig, ... }:

let
  palette = {
    base_silver = "#DADADA"; base_grey = "#B0B0B0"; base_charcoal = "#404040";
    base_offwhite = "#F5F5F5"; base_nearblack = "#2A2A2A"; accent_cyan = "#40E0D0";
    accent_cyan_light = "#7FFFD4"; accent_amber = "#FFBF00"; accent_green = "#32CD32";
    accent_blue = "#4682B4"; accent_blue_light = "#87CEEB"; accent_red_neg = "#CD5C5C";
  };
  futureAviationCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "future-aviation"; # For now this is only used with Hyprland, in the future as other Wayland DEs are added, this can be expanded
in
{
  config = lib.mkIf futureAviationCondition {

    home.packages = with pkgs; [
      font-awesome # Provides 'Font Awesome 6 Free', 'Font Awesome 6 Brands'
      nerd-fonts.jetbrains-mono    # Provides 'JetBrainsMono Nerd Font' and many others
      (pkgs.networkmanagerapplet or null) # For tray network icon, if you use it. Or remove if not.
                                      # The 'or null' is a fallback if the package name isn't exact on your system.
    ];

    programs.waybar = {
      # Settings here will be merged with and can override functional.nix settings
      settings = {
        mainBar = {
          # Example: theme might want a different height
          # height = 32;
        };

        # === Themed Module Settings ===
        "hyprland/workspaces" = {
          format = "{icon}"; # Using icons for workspaces
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            "default" = ""; # Fallback icon
            "urgent" = "";   # Urgent workspace icon
            "persistent" = ""; # Persistent workspace icon (if using)
          };
          # To only show active monitor workspaces (if desired by theme)
          # all-outputs = false;
        };

        "hyprland/window" = {
          # Potentially add themed properties or override max-length if the theme demands it
        };

        clock = {
          format = " {:%a %b %d %H:%M}"; # Themed format with icon
          # tooltip-format is inherited from functional.nix unless overridden
        };

        cpu = {
          format = " {usage}%"; # Themed format with icon
        };

        memory = {
          format = " {}%"; # Themed format with icon
        };

        network = {
          # Overriding functional formats to include theme icons
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ifname}: {ipaddr}/{cidr}";
          format-disconnected = "⚠ Disconnected"; # Themed disconnected state
          # on-click and tooltip-format are inherited
        };

        "pulseaudio#sink_switcher" = {
          # Overriding functional formats to include theme icons and specific styling
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-muted = " Muted";
          format-icons = {
            headphone = "";
            hands-free = ""; # Bluetooth hands-free
            headset = "";    # Bluetooth headset
            phone = "";      # Phone
            portable = "";   # Portable device
            car = "";        # Car audio
            default = ["" ""]; # Default icons (e.g., speakers)
          };
          # scroll-step, on-click, on-click-right are inherited
        };

        tray = {
          icon-size = 18; # Themed icon size for tray items
          # spacing is inherited
        };

        "hyprland/mode" = {
          # Example: if you want to style the mode indicator
          # format = "<span style='italic'>{}</span>";
        };
      }; # End settings

      style = ''
        * {
            font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free', 'Font Awesome 6 Brands';
            font-size: 13px; /* Base font size for the theme */
            border: none; /* Reset borders */
            border-radius: 0; /* Reset border radius */
            min-height: 0; /* Reset min-height */
        }

        window#waybar {
            background-color: rgba(64, 64, 64, 0.8); /* Charcoal base with transparency */
            color: ${palette.base_offwhite};
            transition-property: background-color;
            transition-duration: .5s;
        }

        #workspaces button {
            padding: 0 5px;
            background-color: transparent;
            color: ${palette.base_grey}; /* Default (inactive) workspace color */
        }

        #workspaces button:hover {
            background: rgba(0, 0, 0, 0.2); /* Subtle hover effect */
            box-shadow: inherit; /* Reset any potential shadows */
            text-shadow: inherit;
        }

        #workspaces button.focused {
            color: ${palette.accent_cyan}; /* Active workspace */
            /* You could add a background or border here for more emphasis */
            /* background-color: ${palette.base_nearblack}; */
        }

        #workspaces button.urgent {
            color: ${palette.accent_red_neg}; /* Urgent workspace */
        }

        #mode { /* Hyprland mode indicator (e.g., "resize") */
            padding: 0 10px;
            background-color: ${palette.accent_amber};
            color: ${palette.base_nearblack};
            border-bottom: 3px solid ${palette.base_offwhite}; /* Example distinctive styling */
        }

        /* Common styling for right-aligned modules */
        #clock,
        #cpu,
        #memory,
        #tray,
        #pulseaudio,
        #network {
            padding: 0 10px; /* Horizontal padding */
            margin: 0 4px;   /* Horizontal margin between modules */
            color: ${palette.base_offwhite}; /* Default text color for these modules */
        }
        
        #hyprland-window { /* Center module for window title */
            padding: 0 10px;
            margin: 0 4px;
            color: ${palette.base_offwhite};
        }


        /* Module-specific states */
        #pulseaudio.muted, #pulseaudio button.muted { /* Ensure button state also styled if applicable */
            color: ${palette.accent_amber}; /* Or use accent_red_neg for muted */
        }

        #network.disconnected {
            color: ${palette.accent_red_neg};
        }

        /* Add further detailed styling for other modules or states as needed */
        /* Example:
        #cpu {
            background-color: ${palette.base_charcoal};
        }
        #memory.critical {
            color: ${palette.accent_red_neg};
        }
        */
      ''; # End style
    }; # End programs.waybar
  };
}