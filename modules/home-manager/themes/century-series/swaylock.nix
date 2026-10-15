# ~/nixos-config/modules/home-manager/themes/century-series/swaylock.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Strip # from hex colors for swaylock config
  stripHash = color: builtins.substring 1 6 color;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.swaylock = {
      enable = true;
      package = mkForce pkgs.swaylock-effects;

      # Emptied on purpose: night-mode.nix owns ~/.config/swaylock/config so it
      # can swap day/night. home-manager skips the file when settings == {}.
      settings = { };
    };
  };
}
