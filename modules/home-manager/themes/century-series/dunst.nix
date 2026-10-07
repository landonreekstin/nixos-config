# ~/nixos-config/modules/home-manager/themes/century-series/dunst.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  appThemes = import ./app-themes.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    # The functional layer enables swaync and this theme enables dunst. Both
    # units declare BusName=org.freedesktop.Notifications, and systemd refuses
    # to load EITHER when two units claim one bus name:
    #
    #   dunst.service: Two services allocated for the same bus name
    #   org.freedesktop.Notifications, refusing operation.
    #
    # So the host ran NO notification daemon at all, and every notify-send
    # failed with NameHasNoOwner — silently, for as long as both were enabled.
    # This theme styles dunst in detail and does not style swaync, so dunst is
    # the one that should win here; mkForce over a functional default is the
    # documented way for a theme to make that call.
    services.swaync.enable = mkForce false;

    services.dunst = {
      enable = true;

      settings = appThemes.mkDunstSettings c;
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
