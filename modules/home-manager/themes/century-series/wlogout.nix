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
      background-image: none;
      font-family: "JetBrains Mono Nerd Font", "JetBrains Mono", monospace;
      font-size: 16px;
      font-weight: bold;
    }

    window {
      background-color: rgba(10, 14, 20, 0.7);
    }

    button {
      background-color: ${c.bg-secondary};
      border: 3px solid ${c.border-primary};
      border-radius: 4px;
      margin: 12px;
      padding: 24px 32px;
      color: ${c.text-primary};
      text-shadow: 0 0 10px;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.5);
      min-width: 140px;
      min-height: 100px;
    }

    button:hover {
      background-color: ${c.bg-tertiary};
    }

    button:focus {
      outline: none;
    }

    /* Lock - Secure systems */
    #lock {
      color: ${c.accent-green};
      border-color: ${c.accent-green-dim};
    }
    #lock:hover {
      border-color: ${c.accent-green};
      text-shadow: 0 0 15px ${c.accent-green};
      box-shadow: 0 0 20px ${c.accent-green}, 0 0 40px rgba(0, 255, 65, 0.3);
    }

    /* Logout - Eject */
    #logout {
      color: ${c.caution-yellow};
      border-color: rgba(255, 200, 0, 0.5);
    }
    #logout:hover {
      border-color: ${c.caution-yellow};
      text-shadow: 0 0 15px ${c.caution-yellow};
      box-shadow: 0 0 20px ${c.caution-yellow}, 0 0 40px rgba(255, 200, 0, 0.3);
    }

    /* Suspend - Standby power */
    #suspend {
      color: ${c.accent-amber};
      border-color: ${c.accent-amber-dim};
    }
    #suspend:hover {
      border-color: ${c.accent-amber};
      text-shadow: 0 0 15px ${c.accent-amber};
      box-shadow: 0 0 20px ${c.accent-amber}, 0 0 40px rgba(255, 158, 59, 0.3);
    }

    /* Hibernate - Deep standby */
    #hibernate {
      color: ${c.accent-amber-dim};
      border-color: rgba(180, 110, 40, 0.5);
    }
    #hibernate:hover {
      border-color: ${c.accent-amber-dim};
      text-shadow: 0 0 15px ${c.accent-amber-dim};
      box-shadow: 0 0 20px ${c.accent-amber-dim}, 0 0 40px rgba(180, 110, 40, 0.3);
    }

    /* Shutdown - Engine cut */
    #shutdown {
      color: ${c.warning-red};
      border-color: rgba(255, 56, 56, 0.6);
    }
    #shutdown:hover {
      border-color: ${c.warning-red};
      background-color: rgba(255, 56, 56, 0.15);
      text-shadow: 0 0 15px ${c.warning-red};
      box-shadow: 0 0 25px ${c.warning-red}, 0 0 50px rgba(255, 56, 56, 0.4);
    }

    /* Reboot - Engine restart */
    #reboot {
      color: ${c.info-blue};
      border-color: rgba(82, 139, 255, 0.5);
    }
    #reboot:hover {
      border-color: ${c.info-blue};
      text-shadow: 0 0 15px ${c.info-blue};
      box-shadow: 0 0 20px ${c.info-blue}, 0 0 40px rgba(82, 139, 255, 0.3);
    }
  '';

  # Layout configuration with aviation terminology and Nerd Font icons
  wlogoutLayout = [
    {
      label = "lock";
      action = "swaylock";
      text = "󰌾  SECURE";  # nf-md-lock
      keybind = "l";
    }
    {
      label = "logout";
      action = "hyprctl dispatch exit";
      text = "󰗼  EJECT";  # nf-md-exit_run
      keybind = "e";
    }
    {
      label = "suspend";
      action = "systemctl suspend";
      text = "󰒲  STANDBY";  # nf-md-sleep
      keybind = "s";
    }
    {
      label = "hibernate";
      action = "systemctl hibernate";
      text = "󰋊  DEEP STBY";  # nf-md-harddisk
      keybind = "h";
    }
    {
      label = "shutdown";
      action = "systemctl poweroff";
      text = "󰐥  ENG CUT";  # nf-md-power
      keybind = "p";
    }
    {
      label = "reboot";
      action = "systemctl reboot";
      text = "󰜉  ENG RESTART";  # nf-md-restart
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
