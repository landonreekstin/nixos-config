# ~/nixos-config/modules/home-manager/themes/century-series/rofi.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Rofi theme file content - MFD menu interface
  rofiTheme = ''
    /**
     * Century Series Cockpit Theme for Rofi
     * MFD Menu Interface Aesthetic
     */

    * {
      /* Color definitions */
      bg-primary:      ${c.bg-primary};
      bg-secondary:    ${c.bg-secondary};
      bg-tertiary:     ${c.bg-tertiary};

      border-primary:  ${c.border-primary};
      border-active:   ${c.border-active};

      accent-amber:    ${c.accent-amber};
      accent-green:    ${c.accent-green};

      text-primary:    ${c.text-primary};
      text-secondary:  ${c.text-secondary};
      text-tertiary:   ${c.text-tertiary};

      warning-red:     ${c.warning-red};
      metal:           ${c.metal};

      /* Base settings */
      background-color: transparent;
      text-color:       @text-primary;
      font:             "JetBrains Mono 12";
    }

    /* Main window - MFD screen bezel */
    window {
      background-color: @bg-primary;
      border:           3px solid;
      border-color:     @border-primary;
      border-radius:    0px;
      padding:          0px;
      width:            40%;
      location:         center;
      anchor:           center;
    }

    /* Main container */
    mainbox {
      background-color: @bg-primary;
      padding:          0px;
      spacing:          0px;
      children:         [ inputbar, message, listview, mode-switcher ];
    }

    /* Input bar - Command entry line */
    inputbar {
      background-color: @bg-secondary;
      border:           0px 0px 2px 0px solid;
      border-color:     @border-primary;
      padding:          12px 16px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }

    prompt {
      background-color: @accent-amber;
      text-color:       @bg-primary;
      padding:          4px 12px;
      font:             "JetBrains Mono Bold 11";
      vertical-align:   0.5;
    }

    entry {
      background-color: @bg-tertiary;
      text-color:       @accent-green;
      padding:          4px 12px;
      placeholder:      "ENTER COMMAND...";
      placeholder-color: @text-tertiary;
      cursor:           text;
    }

    /* Message box - Advisory messages */
    message {
      background-color: @bg-secondary;
      border:           0px 0px 1px 0px solid;
      border-color:     @border-primary;
      padding:          8px;
    }

    textbox {
      background-color: transparent;
      text-color:       @accent-amber;
      padding:          4px 8px;
    }

    /* List view - Menu options */
    listview {
      background-color: @bg-primary;
      padding:          8px;
      spacing:          2px;
      scrollbar:        true;
      lines:            10;
      fixed-height:     false;
      cycle:            true;
    }

    /* Scrollbar - MFD scroll indicator */
    scrollbar {
      width:            4px;
      background-color: @bg-secondary;
      handle-color:     @accent-amber;
      border:           0px;
      margin:           0px 4px;
      padding:          0px;
    }

    /* List elements - Menu items */
    element {
      background-color: transparent;
      text-color:       @text-primary;
      padding:          8px 12px;
      border:           1px solid;
      border-color:     transparent;
      spacing:          8px;
    }

    element normal.normal {
      background-color: @bg-secondary;
      text-color:       @text-primary;
      border-color:     @border-primary;
    }

    element normal.urgent {
      background-color: @bg-secondary;
      text-color:       @warning-red;
      border-color:     @warning-red;
    }

    element normal.active {
      background-color: @bg-secondary;
      text-color:       @accent-green;
      border-color:     @accent-green;
    }

    element selected.normal {
      background-color: @accent-amber;
      text-color:       @bg-primary;
      border-color:     @accent-amber;
    }

    element selected.urgent {
      background-color: @warning-red;
      text-color:       @text-primary;
      border-color:     @warning-red;
    }

    element selected.active {
      background-color: @accent-green;
      text-color:       @bg-primary;
      border-color:     @accent-green;
    }

    element-text {
      background-color: transparent;
      text-color:       inherit;
      font:             "JetBrains Mono 11";
      vertical-align:   0.5;
    }

    element-icon {
      background-color: transparent;
      size:             1.2em;
      padding:          0px 4px 0px 0px;
    }

    /* Mode switcher - Function selector */
    mode-switcher {
      background-color: @bg-secondary;
      border:           2px 0px 0px 0px solid;
      border-color:     @border-primary;
      padding:          8px;
      spacing:          4px;
    }

    button {
      background-color: @bg-tertiary;
      text-color:       @text-secondary;
      padding:          6px 12px;
      border:           1px solid;
      border-color:     @border-primary;
      font:             "JetBrains Mono Bold 10";
    }

    button.selected {
      background-color: @accent-green;
      text-color:       @bg-primary;
      border-color:     @accent-green;
    }

    /* Error message */
    error-message {
      background-color: @bg-primary;
      border:           2px solid;
      border-color:     @warning-red;
      padding:          12px;
    }
  '';

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;

      extraConfig = {
        modi = "drun,run,window,ssh";
        show-icons = true;
        display-drun = "LAUNCH";
        display-run = "EXEC";
        display-window = "WINDOW";
        display-ssh = "SSH";
        drun-display-format = "{name}";
        window-format = "{w} · {c} · {t}";
        terminal = "kitty";
        icon-theme = "Papirus-Dark";

        /* Keybindings - Flight stick style */
        kb-mode-next = "Shift+Right,Control+Tab";
        kb-mode-previous = "Shift+Left,Control+ISO_Left_Tab";
        kb-row-up = "Up,Control+k";
        kb-row-down = "Down,Control+j";
        kb-accept-entry = "Return,KP_Enter";
        kb-remove-to-eol = "Control+Shift+e";
        kb-mode-complete = "";
        kb-remove-char-back = "BackSpace";
      };
    };

    # Write theme file
    home.file.".config/rofi/century-cockpit.rasi".text = rofiTheme;

    # Set as default theme
    programs.rofi.theme = "~/.config/rofi/century-cockpit.rasi";
  };
}
