# ~/nixos-config/modules/home-manager/themes/century-series/yazi.nix
# Century Series theme for yazi - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if century-series theme is enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # Yazi theme TOML

in {
  config = mkIf centurySeriesThemeCondition {
    # Install yazi theme

    # Ensure yazi is enabled
    programs.yazi = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}
