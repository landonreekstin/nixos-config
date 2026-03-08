# ~/nixos-config/modules/home-manager/themes/century-series/dunst.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    services.dunst = {
      enable = true;

      settings = {
        global = {
          # Display positioning - Top right like warning light panel
          monitor = 0;
          follow = "mouse";
          origin = "top-right";
          offset = "12x48";  # Below waybar

          # Notification window - Warning light bezel
          width = "(200, 400)";
          height = 300;
          notification_limit = 5;

          # Progress bar - Like fuel/hydraulic gauges
          progress_bar = true;
          progress_bar_height = 10;
          progress_bar_frame_width = 1;
          progress_bar_min_width = 200;
          progress_bar_max_width = 400;

          # Appearance - Cockpit warning panel
          gap_size = 6;
          padding = 12;
          horizontal_padding = 12;
          text_icon_padding = 12;
          frame_width = 2;
          separator_height = 2;
          separator_color = "frame";
          corner_radius = 0;  # Rectangular like warning lights
          transparency = 5;

          # Typography - Military stencil style
          font = "JetBrains Mono Bold 10";
          line_height = 0;
          markup = "full";
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          vertical_alignment = "center";
          show_age_threshold = 60;
          word_wrap = true;
          ellipsize = "middle";
          ignore_newline = false;
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = true;

          # Icons - System status indicators
          icon_position = "left";
          min_icon_size = 24;
          max_icon_size = 48;
          icon_theme = "Papirus-Dark";
          enable_recursive_icon_lookup = true;

          # Interaction - Quick acknowledgment like button press
          mouse_left_click = "do_action, close_current";
          mouse_middle_click = "close_current";
          mouse_right_click = "close_all";

          # Timing - Warning light persistence
          idle_threshold = 120;
          sticky_history = true;
          history_length = 20;

          # Wayland specific
          layer = "overlay";
          force_xwayland = false;
        };

        # Urgency: Low - Advisory/Informational (Blue)
        urgency_low = {
          background = c.bg-secondary;
          foreground = c.info-blue;
          frame_color = c.info-blue;
          highlight = c.info-blue;
          timeout = 5;
        };

        # Urgency: Normal - Caution (Amber)
        urgency_normal = {
          background = c.bg-secondary;
          foreground = c.accent-amber;
          frame_color = c.accent-amber;
          highlight = c.accent-amber;
          timeout = 8;
        };

        # Urgency: Critical - Warning/Master Caution (Red)
        urgency_critical = {
          background = c.bg-primary;
          foreground = c.warning-red;
          frame_color = c.warning-red;
          highlight = c.warning-red;
          timeout = 0;  # Requires acknowledgment
        };

        # Custom rules for specific notification types

        # Volume notifications - Audio system
        volume = {
          appname = "volume";
          urgency = "low";
          background = c.bg-secondary;
          foreground = c.accent-amber;
          frame_color = c.accent-amber-dim;
          format = "<b>VOL</b> %b";
          timeout = 2;
        };

        # Brightness notifications - Display brightness
        brightness = {
          appname = "brightness";
          urgency = "low";
          background = c.bg-secondary;
          foreground = c.accent-green;
          frame_color = c.accent-green-dim;
          format = "<b>BRT</b> %b";
          timeout = 2;
        };

        # Battery notifications - Electrical system warnings
        battery_low = {
          appname = "battery";
          urgency = "critical";
          background = c.bg-primary;
          foreground = c.warning-red;
          frame_color = c.warning-red;
          format = "<b>⚠ BATTERY LOW</b>\\n%b";
        };

        battery_critical = {
          appname = "battery";
          summary = "*critical*";
          urgency = "critical";
          background = c.bg-primary;
          foreground = c.warning-red;
          frame_color = c.warning-red;
          format = "<b>⚠ BATTERY CRITICAL</b>\\n%b";
        };

        # Network notifications - Data link status
        network = {
          appname = "network";
          urgency = "low";
          background = c.bg-secondary;
          foreground = c.accent-green;
          frame_color = c.accent-green;
          format = "<b>LINK</b> %b";
          timeout = 4;
        };

        # System updates - Maintenance advisory
        updates = {
          appname = "update";
          urgency = "normal";
          background = c.bg-secondary;
          foreground = c.caution-yellow;
          frame_color = c.caution-yellow;
          format = "<b>SYS UPDATE</b>\\n%b";
        };

        # Screenshot notifications - Capture confirmation
        screenshot = {
          appname = "screenshot";
          urgency = "low";
          background = c.bg-secondary;
          foreground = c.accent-green;
          frame_color = c.accent-green;
          format = "<b>CAPTURE</b> %b";
          timeout = 3;
        };
      };
    };

    # Script for volume notifications with proper formatting
    home.packages = with pkgs; [
      libnotify  # For notify-send
      dunst      # Notification daemon
    ];

    # Example notification script for testing
    home.file.".local/bin/century-notify-test" = {
      text = ''
        #!/usr/bin/env bash
        # Test notifications for Century Series theme

        echo "Testing Century Series notification theme..."

        # Low urgency (Info - Blue)
        notify-send -u low "ADVISORY" "System nominal - all instruments green"
        sleep 2

        # Normal urgency (Caution - Amber)
        notify-send -u normal "CAUTION" "High memory usage detected"
        sleep 2

        # Critical urgency (Warning - Red)
        notify-send -u critical "WARNING" "Critical system temperature"
        sleep 2

        # Volume notification
        notify-send -a volume "Volume" "65%"
        sleep 2

        # Network notification
        notify-send -a network "Network Connected" "WiFi: CLASSIFIED-NET"

        echo "Test complete."
      '';
      executable = true;
    };
  };
}
