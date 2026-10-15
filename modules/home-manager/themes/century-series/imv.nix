# ~/nixos-config/modules/home-manager/themes/century-series/imv.nix
# Century Series theme for imv - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # imv takes colors as 6-digit RRGGBB, optionally with a leading '#'. An 8-digit
  # RRGGBBAA value is *not* accepted: imv prints "Invalid hex color" and then
  # aborts on the whole config file, so a single bad colour makes imv exit 1 on
  # every image. Overlay opacity is a separate option (overlay_background_alpha).
  hex = s: lib.removePrefix "#" s;

in {
  config = mkIf centurySeriesThemeCondition {

    home.packages = [ pkgs.imv ];
  };
}
