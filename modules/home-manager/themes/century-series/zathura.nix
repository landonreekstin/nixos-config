# ~/nixos-config/modules/home-manager/themes/century-series/zathura.nix
# Century Series theme for zathura - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  colorsModule = import ./colors.nix { };
  appThemes = import ./app-themes.nix { inherit lib; };
  c = colorsModule.centuryColors;

  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";
in {
  config = mkIf centurySeriesThemeCondition {
    programs.zathura = {
      enable = true;
      options = appThemes.zathuraOptions;
      # Colours live in an included file so night mode can swap them; zathura
      # has no reload, so this takes effect the next time it is opened.
      extraConfig = "include ${config.home.homeDirectory}/.config/zathura/century-colors";
    };
  };
}
