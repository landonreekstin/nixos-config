# ~/nixos-config/modules/home-manager/themes/century-series/wlogout.nix
# Century Series wlogout theme - Aviation engine control panel aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if century-series theme is enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # Flat annunciator tile - dim / un-lit state
  # width/height at 4x the viewBox force high-res rasterization so text stays
  # crisp when wlogout scales the SVG up to fill the button.

  # CSS styling for wlogout - Engine Control Panel aesthetic
  wlogoutStyle = ''
    /* Day/night palette, swapped by night-mode.nix. The URL must be absolute:
       a relative one resolves against this stylesheet's /nix/store path, not
       ~/.config/wlogout. Same shape as the waybar palette. */
    @import url("file://${config.home.homeDirectory}/.config/wlogout/century-colors.css");

    /* Century Series Engine Control Panel */
    * {
      background-image: none;
      font-family: "JetBrains Mono Nerd Font", "JetBrains Mono", monospace;
      font-size: 16px;
      font-weight: bold;
    }

    window {
      background-color: @c_window;
    }

    button {
      background-color: transparent;
      background-repeat: no-repeat;
      background-position: center center;
      background-size: contain;
      border: none;
      border-radius: 0;
      margin: 5px;
      padding: 0;
      color: transparent;
      min-width: 140px;
      min-height: 180px;
    }

    button:focus {
      outline: none;
    }

    /* Lock */
    #lock { background-image: url("icons/switch-green.svg"); }
    #lock:hover { background-image: url("icons/switch-green-hover.svg"); }

    /* Logout */
    #logout { background-image: url("icons/switch-yellow.svg"); }
    #logout:hover { background-image: url("icons/switch-yellow-hover.svg"); }

    /* Suspend */
    #suspend { background-image: url("icons/switch-amber.svg"); }
    #suspend:hover { background-image: url("icons/switch-amber-hover.svg"); }

    /* Hibernate */
    #hibernate { background-image: url("icons/switch-amber-dim.svg"); }
    #hibernate:hover { background-image: url("icons/switch-amber-dim-hover.svg"); }

    /* Shutdown */
    #shutdown { background-image: url("icons/switch-red.svg"); }
    #shutdown:hover { background-image: url("icons/switch-red-hover.svg"); }

    /* Reboot */
    #reboot { background-image: url("icons/switch-blue.svg"); }
    #reboot:hover { background-image: url("icons/switch-blue-hover.svg"); }
  '';

  # Layout configuration - labels are in SVG images
  wlogoutLayout = [
    {
      label = "lock";
      action = "swaylock";
      text = "";
      keybind = "l";
    }
    {
      label = "logout";
      action = "hyprctl dispatch exit";
      text = "";
      keybind = "e";
    }
    {
      label = "suspend";
      action = "systemctl suspend";
      text = "";
      keybind = "s";
    }
    {
      label = "hibernate";
      action = "systemctl hibernate";
      text = "";
      keybind = "h";
    }
    {
      label = "shutdown";
      action = "systemctl poweroff";
      text = "";
      keybind = "p";
    }
    {
      label = "reboot";
      action = "systemctl reboot";
      text = "";
      keybind = "r";
    }
  ];

  # Image directory
  imgDir = "${config.home.homeDirectory}/.config/wlogout/icons";

in {
  config = mkIf centurySeriesThemeCondition {
    # Create switch SVG images with labels
    # The twelve annunciator SVGs are written by night-mode.nix, not here:
    # their colour is baked into each file, so the night variant is a
    # different SVG rather than a restyle.

    programs.wlogout = {
      enable = true;
      layout = wlogoutLayout;
      style = wlogoutStyle;
    };
  };
}
