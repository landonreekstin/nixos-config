# ~/nixos-config/modules/home-manager/themes/century-series/hyprlock.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Hex color (#rrggbb) + alpha hex (ff = opaque) → hyprlock rgba(rrggbbaa)
  rgba = hex: alpha:
    let stripped = builtins.substring 1 6 hex;
    in "rgba(${stripped}${alpha})";

  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";
in {
  config = mkIf centurySeriesThemeCondition {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          hide_cursor             = true;
          grace                   = 0;
          no_fade_in              = false;
          no_fade_out             = false;
          ignore_empty_input      = false;
        };

        # ─── Background ─────────────────────────────────────────────────────── #
        # Blurred screenshot, dimmed — like looking through a tinted canopy
        background = [{
          path            = "screenshot";
          blur_passes     = 3;
          blur_size       = 7;
          noise           = 0.0117;
          contrast        = 0.9;
          brightness      = 0.5;
          vibrancy        = 0.1;
          vibrancy_darkness = 0.0;
        }];

        # ─── Input Field ─────────────────────────────────────────────────────── #
        # Square MFD data-entry box with amber outline
        input-field = [{
          size            = "320, 52";
          outline_thickness = 3;
          dots_size       = 0.25;
          dots_spacing    = 0.2;
          dots_center     = true;
          dots_rounding   = -1;            # Square dots to match MFD aesthetic

          outer_color     = rgba c.accent-amber "ff";
          inner_color     = rgba c.bg-secondary "ee";
          font_color      = rgba c.accent-amber-glow "ff";

          fade_on_empty   = true;
          placeholder_text = ''<span font_family="JetBrains Mono" foreground="#a6a69c" font_size="11">ENTER ACCESS CODE</span>'';

          hide_input      = false;
          rounding        = 0;             # Hard corners — MFD not rounded consumer UI

          check_color     = rgba c.accent-amber "ff";
          fail_color      = rgba c.warning-red "ff";
          fail_text       = ''<span font_family="JetBrains Mono" foreground="#ff3838" font_size="11">ACCESS DENIED</span>'';
          fail_transition = 300;
          capslock_color  = rgba c.caution-yellow "ff";

          position        = "0, 60";
          halign          = "center";
          valign          = "center";
        }];

        # ─── Labels ──────────────────────────────────────────────────────────── #
        label = [

          # Cockpit chronometer — large amber clock face
          # Positioned above center like a primary flight instrument
          {
            text         = ''cmd[update:1000] date +"%-H:%M"'';
            color        = rgba c.accent-amber "ff";
            font_size    = 96;
            font_family  = "JetBrains Mono Bold";
            shadow_passes = 2;
            shadow_size  = 6;
            shadow_color = rgba c.bg-primary "cc";
            position     = "0, -160";
            halign       = "center";
            valign       = "center";
          }

          # Date — small instrument marking below the clock
          {
            text         = ''cmd[update:60000] date +"%A  %Y-%m-%d"'';
            color        = rgba c.text-secondary "cc";
            font_size    = 14;
            font_family  = "JetBrains Mono";
            position     = "0, -60";
            halign       = "center";
            valign       = "center";
          }

          # Authentication required — phosphor green advisory line
          {
            text         = "AUTHENTICATION REQUIRED";
            color        = rgba c.accent-green "dd";
            font_size    = 11;
            font_family  = "JetBrains Mono";
            position     = "0, 15";
            halign       = "center";
            valign       = "center";
          }

          # Username — below input field
          {
            text         = "$USER";
            color        = rgba c.text-tertiary "cc";
            font_size    = 12;
            font_family  = "JetBrains Mono";
            position     = "0, 128";
            halign       = "center";
            valign       = "center";
          }

          # Corner classification marker — top-left
          {
            text         = "RESTRICTED // EYES ONLY";
            color        = rgba c.warning-red "55";
            font_size    = 9;
            font_family  = "JetBrains Mono";
            position     = "20, -20";
            halign       = "left";
            valign       = "top";
          }

          # Footer — tactical system identifier
          {
            text         = "CENTURY SERIES // TACTICAL SYSTEMS";
            color        = rgba c.text-tertiary "66";
            font_size    = 9;
            font_family  = "JetBrains Mono";
            position     = "0, 20";
            halign       = "center";
            valign       = "bottom";
          }

        ];
      };
    };
  };
}
