# ~/nixos-config/modules/home-manager/themes/century-series/btop.nix
# Century Series theme for btop - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if century-series theme is enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # btop theme file content

in {
  config = mkIf centurySeriesThemeCondition {
    # Install btop theme

    # Configure btop to use the theme
    # Note: btop package is installed separately (btop-rocm in functional.nix)
    programs.btop = {
      enable = true;
      package = pkgs.btop-rocm;
      settings = {
        color_theme = "century-series";
        theme_background = true;
        vim_keys = true;
      };
    };
  };
}
