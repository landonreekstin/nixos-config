# ~/nixos-config/modules/home-manager/themes/century-series/theme.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Cold War Aviation Cockpit Color Palette
  colors = {
    # Base colors - Instrument panel backgrounds
    bg-primary = "#0a0e14";      # Deep panel black
    bg-secondary = "#1a1f29";    # Secondary panel
    bg-tertiary = "#141920";     # Raised elements

    # Structural colors - MFD frames and bezels
    border-primary = "#2a3441";   # Gunmetal frame
    border-secondary = "#3d4654"; # Lighter bezel
    border-active = "#4a5568";    # Active/focused frame

    # Primary accent - Amber CRT displays (radar altimeter, navigation)
    accent-amber = "#ff9e3b";     # Main amber
    accent-amber-dim = "#cc7e2f"; # Dimmed amber
    accent-amber-glow = "#ffb454"; # Glowing amber

    # Secondary accent - Green phosphor (attitude indicator, radar)
    accent-green = "#7fda89";     # Phosphor green
    accent-green-dim = "#5cb36a"; # Dimmed green
    accent-radar = "#39ff14";     # Intense radar green

    # Text colors - Instrument markings
    text-primary = "#e6e1cf";     # Off-white markings
    text-secondary = "#a6a69c";   # Dimmed text
    text-tertiary = "#6a6a5e";    # Very dim text

    # Warning/Caution system
    warning-red = "#ff3838";      # Master warning
    caution-yellow = "#ffb454";   # Caution/advisory
    info-blue = "#5ccfe6";        # Information

    # Material colors
    metal = "#4a5568";            # Brushed aluminum
    metal-dark = "#2d3748";       # Dark steel
    glass = "#1a1f2980";          # Tinted glass overlay
  };

  # Configuration object (can be extended in the future for accent mode, border style, etc.)
  centuryConfig = {
    accentMode = "mixed";  # Future: could be made configurable via customConfig
    borderStyle = "mfd";   # Future: could be made configurable via customConfig
  };

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./rofi.nix
    ./kitty.nix
    ./dunst.nix
  ];

  # Pass colors and config to all components via module args
  _module.args = {
    centuryColors = colors;
    centuryConfig = centuryConfig;
  };

  config = mkIf centurySeriesThemeCondition {
    # Additional styling packages
    home.packages = with pkgs; [
      # Font for aviation-style numerals and text
      jetbrains-mono
      fira-code
      # Icon theme that works well with the aesthetic
      papirus-icon-theme
    ];

    # GTK theme for consistency
    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    # Cursor theme
    home.pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
    };
  };
}
