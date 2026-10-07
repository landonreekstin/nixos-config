# ~/nixos-config/modules/home-manager/themes/century-series/rofi.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;

      extraConfig = {
        # Display settings
        modi = "drun,run,window";
        show-icons = true;
        icon-theme = "Papirus-Dark";
        terminal = "kitty";
        drun-display-format = "{name}";
        disable-history = false;
        sort = true;
        sorting-method = "fzf";
        case-sensitive = false;

        # MFD-style prompt
        display-drun = "LAUNCH";
        display-run = "EXEC";
        display-window = "WINDOWS";
      };

      theme = let
        inherit (config.lib.formats.rasi) mkLiteral;
      in {
        # Colours come from an @import'ed file that night mode swaps — the same
        # shape as waybar. home-manager's toRasi emits a top-level "@import"
        # key before everything else, and the 45 "@name" references below
        # resolve against it. rofi reads the theme at launch, so an open rofi
        # keeps the old palette until it is reopened.
        "@import" = "${config.home.homeDirectory}/.config/rofi/century-colors.rasi";

        "*" = {
          font = "JetBrains Mono 11";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@text-primary";
        };

        # Main window - MFD screen with button bezel frame
        window = {
          width = mkLiteral "620px";
          height = mkLiteral "500px";
          background-color = mkLiteral "@bg-tertiary";
          border = mkLiteral "4px solid";
          border-color = mkLiteral "@metal";
          border-radius = mkLiteral "0px";
          # Outer padding creates the MFD button frame area
          padding = mkLiteral "24px";
        };

        # Main container - the actual screen area
        mainbox = {
          background-color = mkLiteral "@bg-primary";
          children = map mkLiteral [ "inputbar" "message" "listview" "mode-switcher" ];
          spacing = mkLiteral "0px";
          padding = mkLiteral "0px";
          border = mkLiteral "3px solid";
          border-color = mkLiteral "@border-color";
        };

        # Input field - Command entry line
        inputbar = {
          background-color = mkLiteral "@bg-secondary";
          padding = mkLiteral "12px 16px";
          border = mkLiteral "0px 0px 2px 0px solid";
          border-color = mkLiteral "@border-color";
          children = map mkLiteral [ "prompt" "entry" ];
          spacing = mkLiteral "12px";
        };

        prompt = {
          text-color = mkLiteral "@accent-amber";
          font = "JetBrains Mono Bold 11";
        };

        entry = {
          text-color = mkLiteral "@accent-green";
          placeholder = "Search...";
          placeholder-color = mkLiteral "@text-secondary";
        };

        # Message area
        message = {
          background-color = mkLiteral "@bg-secondary";
          padding = mkLiteral "8px";
          border = mkLiteral "0px 0px 1px 0px solid";
          border-color = mkLiteral "@border-color";
        };

        textbox = {
          text-color = mkLiteral "@text-secondary";
        };

        # Results list
        listview = {
          background-color = mkLiteral "@bg-primary";
          padding = mkLiteral "8px";
          columns = mkLiteral "1";
          lines = mkLiteral "10";
          spacing = mkLiteral "4px";
          scrollbar = false;
          fixed-height = true;
        };

        # Individual menu entries - MFD menu items
        element = {
          background-color = mkLiteral "@bg-secondary";
          padding = mkLiteral "8px 12px";
          border = mkLiteral "1px solid";
          border-color = mkLiteral "@border-color";
          border-radius = mkLiteral "0px";
          spacing = mkLiteral "8px";
        };

        element-text = {
          text-color = mkLiteral "inherit";
          highlight = mkLiteral "bold @accent-amber";
        };

        element-icon = {
          size = mkLiteral "24px";
          background-color = mkLiteral "inherit";
        };

        # Normal states
        "element normal.normal" = {
          background-color = mkLiteral "@bg-secondary";
          text-color = mkLiteral "@text-primary";
        };

        "element normal.active" = {
          background-color = mkLiteral "@bg-secondary";
          text-color = mkLiteral "@accent-green";
        };

        "element normal.urgent" = {
          background-color = mkLiteral "@bg-secondary";
          text-color = mkLiteral "@warning-red";
        };

        # Selected states - Dark text on bright background for contrast
        "element selected.normal" = {
          background-color = mkLiteral "@accent-amber";
          text-color = mkLiteral "@text-dark";
          border-color = mkLiteral "@accent-amber";
        };

        "element-text selected.normal" = {
          text-color = mkLiteral "@text-dark";
          highlight = mkLiteral "bold @highlight-match";
        };

        "element selected.active" = {
          background-color = mkLiteral "@accent-green";
          text-color = mkLiteral "@text-dark";
          border-color = mkLiteral "@accent-green";
        };

        "element-text selected.active" = {
          text-color = mkLiteral "@text-dark";
          highlight = mkLiteral "bold @highlight-match";
        };

        "element selected.urgent" = {
          background-color = mkLiteral "@warning-red";
          text-color = mkLiteral "@text-dark";
          border-color = mkLiteral "@warning-red";
        };

        "element-text selected.urgent" = {
          text-color = mkLiteral "@text-dark";
          highlight = mkLiteral "bold @highlight-match";
        };

        # Alternate row styling (subtle)
        "element alternate.normal" = {
          background-color = mkLiteral "@bg-secondary";
        };

        # Mode switcher - MFD bottom button row
        mode-switcher = {
          background-color = mkLiteral "@bg-tertiary";
          padding = mkLiteral "8px 4px";
          border = mkLiteral "2px 0px 0px 0px solid";
          border-color = mkLiteral "@border-color";
          spacing = mkLiteral "4px";
          expand = false;
        };

        # MFD-style buttons
        button = {
          background-color = mkLiteral "@bg-secondary";
          text-color = mkLiteral "@text-secondary";
          padding = mkLiteral "10px 20px";
          border = mkLiteral "2px solid";
          border-color = mkLiteral "@border-active";
          border-radius = mkLiteral "2px";
          font = "JetBrains Mono Bold 9";
          horizontal-align = mkLiteral "0.5";
        };

        "button selected" = {
          background-color = mkLiteral "@accent-amber";
          text-color = mkLiteral "@text-dark";
          border-color = mkLiteral "@accent-amber";
        };

        "button hover" = {
          background-color = mkLiteral "@border-active";
          text-color = mkLiteral "@text-primary";
        };
      };
    };
  };
}
