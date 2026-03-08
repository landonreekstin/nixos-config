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

      settings = {
        # ============================================
        # Century Series Cockpit Lock Screen
        # MFD Security Interface Aesthetic
        # ============================================

        # Background - Deep instrument panel black
        color = stripHash c.bg-primary;

        # Indicator ring - Cockpit gauge aesthetic
        indicator = true;
        indicator-radius = 120;
        indicator-thickness = 8;
        indicator-caps-lock = true;

        # Ring colors - MFD frame with amber/green accents
        ring-color = stripHash c.border-primary;
        ring-ver-color = stripHash c.accent-amber;
        ring-wrong-color = stripHash c.warning-red;
        ring-clear-color = stripHash c.accent-green;

        # Key highlight - Amber glow on keypress
        key-hl-color = stripHash c.accent-amber-glow;
        bs-hl-color = stripHash c.caution-yellow;

        # Separator - Gunmetal frame line
        separator-color = stripHash c.border-primary;

        # Inside ring colors - Panel backgrounds
        inside-color = stripHash c.bg-secondary;
        inside-ver-color = stripHash c.bg-secondary;
        inside-wrong-color = stripHash c.bg-secondary;
        inside-clear-color = stripHash c.bg-secondary;

        # Line between ring and inside
        line-color = stripHash c.border-primary;
        line-ver-color = stripHash c.accent-amber-dim;
        line-wrong-color = stripHash c.warning-red;
        line-clear-color = stripHash c.accent-green-dim;

        # Text colors - Instrument markings
        text-color = stripHash c.text-primary;
        text-ver-color = stripHash c.accent-amber;
        text-wrong-color = stripHash c.warning-red;
        text-clear-color = stripHash c.accent-green;
        text-caps-lock-color = stripHash c.caution-yellow;

        # Layout text - Military stencil style
        layout-text-color = stripHash c.text-secondary;

        # Font - Aviation instrument style
        font = "JetBrains Mono";
        font-size = 24;

        # Custom text - Aviation terminology
        text = "SECURE";
        text-ver = "AUTHENTICATING";
        text-wrong = "ACCESS DENIED";
        text-clear = "CLEARED";
        text-caps-lock = "CAPS ACTIVE";

        # Effects (swaylock-effects features)
        clock = true;
        timestr = "%H:%M";
        datestr = "%Y-%m-%d";

        # Fade effect for cockpit power-up feel
        fade-in = 0.2;

        # Grace period - Allow immediate unlock briefly after lock
        grace = 2;
        grace-no-mouse = true;
        grace-no-touch = true;

        # Disable fingerprint indicator (not aviation-themed)
        disable-caps-lock-text = false;
        ignore-empty-password = true;
        show-failed-attempts = true;

        # Screenshot as background (shows current workspace dimmed)
        screenshots = true;

        # Dim and blur effect - Like looking through tinted canopy
        effect-blur = "8x5";
        effect-vignette = "0.5:0.5";
        effect-greyscale = false;

        # Scaling
        scaling = "fill";
      };
    };
  };
}
