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
    xdg.configFile."imv/config".text = ''
      [options]
      background=${hex c.bg-primary}
      overlay_font=JetBrains Mono:11
      overlay_text_color=${hex c.accent-amber}
      overlay_background_color=${hex c.bg-secondary}
      overlay_background_alpha=cc
      overlay_position_bottom=false
      # There is no "full_pixel" in imv: initial_zoom is not an option at all and
      # scaling_mode only takes none/shrink/full/crop, so the old pair of
      # full_pixel lines was a second fatal config error hiding behind the colours.
      # shrink fits an oversized photo to the window without blowing up a small
      # one; nearest_neighbour keeps zoomed-in pixels crisp rather than smeared.
      scaling_mode=shrink
      upscaling_method=nearest_neighbour
      loop_input=true
      title_text=[imv] $current_file ($width x $height) [$scale% — $current/$total]
    '';

    home.packages = [ pkgs.imv ];
  };
}
