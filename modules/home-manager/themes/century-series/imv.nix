# ~/nixos-config/modules/home-manager/themes/century-series/imv.nix
# Century Series theme for imv - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # imv config requires colors as RRGGBBAA hex without the leading '#'
  hex = s: lib.removePrefix "#" s;

in {
  config = mkIf centurySeriesThemeCondition {
    xdg.configFile."imv/config".text = ''
      [options]
      background=${hex c.bg-primary}
      overlay_font=JetBrains Mono:11
      overlay_text_color=${hex c.accent-amber}ff
      overlay_background_color=${hex c.bg-secondary}cc
      overlay_position_bottom=false
      initial_zoom=full_pixel
      scaling_mode=full_pixel
      loop_input=true
      title_text=[imv] $current_file ($width x $height) [$scale% — $current/$total]
    '';

    home.packages = [ pkgs.imv ];
  };
}
