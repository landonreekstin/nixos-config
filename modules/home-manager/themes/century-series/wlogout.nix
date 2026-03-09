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

  # CSS styling for wlogout - Engine Control Panel aesthetic
  wlogoutStyle = ''
    /* Century Series Engine Control Panel */
    * {
      font-family: "JetBrains Mono", monospace;
      font-size: 14px;
    }

    window {
      background-color: rgba(10, 14, 20, 0.85);
    }

    button {
      background-color: ${c.bg-secondary};
      border: 3px solid ${c.border-primary};
      border-radius: 0px;
      margin: 10px;
      padding: 20px;
      color: ${c.text-primary};
      transition: all 0.2s ease;
    }

    button:hover {
      background-color: ${c.bg-tertiary};
      border-color: ${c.accent-amber};
    }

    button:focus {
      background-color: ${c.bg-tertiary};
      border-color: ${c.accent-amber};
      outline: none;
    }

    /* Lock - Secure systems */
    #lock {
      color: ${c.accent-green};
    }
    #lock:hover {
      border-color: ${c.accent-green};
    }

    /* Logout - Eject */
    #logout {
      color: ${c.caution-yellow};
    }
    #logout:hover {
      border-color: ${c.caution-yellow};
    }

    /* Suspend - Standby power */
    #suspend {
      color: ${c.accent-amber};
    }
    #suspend:hover {
      border-color: ${c.accent-amber};
    }

    /* Hibernate - Deep standby */
    #hibernate {
      color: ${c.accent-amber-dim};
    }
    #hibernate:hover {
      border-color: ${c.accent-amber-dim};
    }

    /* Shutdown - Engine cut */
    #shutdown {
      color: ${c.warning-red};
    }
    #shutdown:hover {
      border-color: ${c.warning-red};
      background-color: rgba(255, 56, 56, 0.1);
    }

    /* Reboot - Engine restart */
    #reboot {
      color: ${c.info-blue};
    }
    #reboot:hover {
      border-color: ${c.info-blue};
    }
  '';

  # Layout configuration with aviation terminology
  wlogoutLayout = [
    {
      label = "lock";
      action = "swaylock";
      text = "SECURE";
      keybind = "l";
    }
    {
      label = "logout";
      action = "hyprctl dispatch exit";
      text = "EJECT";
      keybind = "e";
    }
    {
      label = "suspend";
      action = "systemctl suspend";
      text = "STANDBY";
      keybind = "s";
    }
    {
      label = "hibernate";
      action = "systemctl hibernate";
      text = "DEEP STBY";
      keybind = "h";
    }
    {
      label = "shutdown";
      action = "systemctl poweroff";
      text = "ENG CUT";
      keybind = "p";
    }
    {
      label = "reboot";
      action = "systemctl reboot";
      text = "ENG RESTART";
      keybind = "r";
    }
  ];

in {
  config = mkIf centurySeriesThemeCondition {
    programs.wlogout = {
      enable = true;
      layout = wlogoutLayout;
      style = wlogoutStyle;
    };
  };
}
