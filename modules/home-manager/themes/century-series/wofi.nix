# ~/nixos-config/modules/home-manager/themes/century-series/wofi.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Wofi CSS theme - MFD menu interface
  wofiCSS = ''
    /**
     * Century Series Cockpit Theme for Wofi
     * MFD Menu Interface Aesthetic
     */

    * {
      font-family: "JetBrains Mono", monospace;
      font-size: 12px;
      font-weight: normal;
    }

    /* Main window - MFD screen bezel */
    window {
      background-color: ${c.bg-primary};
      border: 3px solid ${c.border-primary};
      border-radius: 0px;
    }

    /* Input field - Command entry line */
    #input {
      background-color: ${c.bg-secondary};
      border: 0px 0px 2px 0px solid ${c.border-primary};
      color: ${c.accent-green};
      padding: 12px 16px;
      margin: 0px;
      border-radius: 0px;
    }

    #input:focus {
      border-color: ${c.accent-amber};
      outline: none;
    }

    /* Inner box containing the entries */
    #inner-box {
      background-color: ${c.bg-primary};
      padding: 8px;
      margin: 0px;
    }

    /* Outer box - main container */
    #outer-box {
      background-color: ${c.bg-primary};
      padding: 0px;
      margin: 0px;
    }

    /* Scroll area */
    #scroll {
      background-color: ${c.bg-primary};
      margin: 0px;
      padding: 0px;
    }

    /* Individual menu entries - MFD menu items */
    #entry {
      background-color: ${c.bg-secondary};
      color: ${c.text-primary};
      padding: 8px 12px;
      margin: 2px 0px;
      border: 1px solid ${c.border-primary};
      border-radius: 0px;
    }

    #entry:hover {
      background-color: ${c.accent-amber};
      color: ${c.bg-primary};
      border-color: ${c.accent-amber};
    }

    #entry:selected {
      background-color: ${c.accent-amber};
      color: ${c.bg-primary};
      border-color: ${c.accent-amber};
    }

    #entry.urgent {
      background-color: ${c.bg-secondary};
      color: ${c.warning-red};
      border-color: ${c.warning-red};
    }

    #entry.urgent:selected {
      background-color: ${c.warning-red};
      color: ${c.text-primary};
      border-color: ${c.warning-red};
    }

    /* Entry text */
    #text {
      color: inherit;
      font-family: "JetBrains Mono", monospace;
      font-size: 11px;
    }

    /* Entry icons */
    #img {
      margin-right: 8px;
    }

    /* No results message */
    #no-results {
      color: ${c.text-tertiary};
      padding: 20px;
      text-align: center;
    }
  '';

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.wofi = {
      enable = true;
      
      settings = {
        # Display settings
        width = 600;
        height = 400;
        location = "center";
        show = "drun";
        prompt = "LAUNCH";
        filter_rate = 100;
        allow_markup = true;
        no_actions = true;
        halign = "fill";
        orientation = "vertical";
        content_halign = "fill";
        insensitive = true;
        allow_images = true;
        image_size = 24;
        gtk_dark = true;

        # MFD-style configuration
        lines = 10;
        columns = 1;
        matching = "contains";
        sort_order = "alphabetical";
        term = "kitty";
        
        # Hide scroll bars for clean MFD look
        hide_scroll = true;
      };

      style = wofiCSS;
    };
  };
}