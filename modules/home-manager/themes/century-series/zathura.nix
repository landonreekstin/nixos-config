# ~/nixos-config/modules/home-manager/themes/century-series/zathura.nix
# Century Series theme for zathura - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";
in {
  config = mkIf centurySeriesThemeCondition {
    programs.zathura = {
      enable = true;
      options = {
        # Instrument panel backgrounds
        default-bg            = c.bg-primary;
        default-fg            = c.text-primary;

        # Status bar — lower MFD strip
        statusbar-bg          = c.bg-secondary;
        statusbar-fg          = c.accent-amber;
        statusbar-h-padding   = 8;
        statusbar-v-padding   = 4;

        # Input bar — targeting computer prompt
        inputbar-bg           = c.bg-secondary;
        inputbar-fg           = c.accent-amber-glow;

        # Notification bar
        notification-bg       = c.bg-secondary;
        notification-fg       = c.text-primary;
        notification-error-bg = c.warning-red;
        notification-error-fg = c.bg-primary;
        notification-warning-bg = c.caution-yellow;
        notification-warning-fg = c.bg-primary;

        # Selection — radar lock-on highlight
        highlight-color         = c.accent-amber;
        highlight-active-color  = c.accent-amber-glow;

        # Completion menu
        completion-bg           = c.bg-secondary;
        completion-fg           = c.text-primary;
        completion-highlight-bg = c.accent-amber;
        completion-highlight-fg = c.bg-primary;

        # Index view (table of contents)
        index-bg                = c.bg-primary;
        index-fg                = c.text-primary;
        index-active-bg         = c.accent-amber;
        index-active-fg         = c.bg-primary;

        # Loading indicator
        render-loading-bg       = c.bg-primary;
        render-loading-fg       = c.accent-green;

        # Recolor (dark mode) — invert PDF pages to match cockpit aesthetic
        recolor                 = true;
        recolor-lightcolor      = c.bg-primary;
        recolor-darkcolor       = c.text-primary;
        recolor-keephue         = false;
      };
    };
  };
}
