# ~/nixos-config/modules/home-manager/themes/century-series/theme.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  colors = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./kitty.nix
    ./dunst.nix
  ];

  # Module arguments are passed differently in NixOS
  # Colors and config will be passed via individual module files

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
