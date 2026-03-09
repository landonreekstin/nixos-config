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
      font-family: "JetBrains Mono Nerd Font", "JetBrains Mono", monospace;
      font-size: 16px;
      font-weight: bold;
    }

    window {
      background-color: rgba(10, 14, 20, 0.92);
    }

    button {
      background: linear-gradient(180deg, ${c.bg-tertiary} 0%, ${c.bg-secondary} 50%, ${c.bg-primary} 100%);
      border: 3px solid ${c.border-primary};
      border-radius: 4px;
      margin: 12px;
      padding: 24px 32px;
      color: ${c.text-primary};
      text-shadow: 0 0 8px currentColor;
      transition: all 0.2s ease;
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.05),
        inset 0 -2px 4px rgba(0, 0, 0, 0.3),
        0 4px 8px rgba(0, 0, 0, 0.5);
      min-width: 140px;
      min-height: 100px;
    }

    button:hover {
      transform: scale(1.02);
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        inset 0 -2px 4px rgba(0, 0, 0, 0.3),
        0 6px 16px rgba(0, 0, 0, 0.6),
        0 0 20px currentColor;
    }

    button:focus {
      outline: none;
    }

    button:active {
      transform: scale(0.98);
      box-shadow:
        inset 0 2px 4px rgba(0, 0, 0, 0.4),
        0 2px 4px rgba(0, 0, 0, 0.4);
    }

    /* Lock - Secure systems */
    #lock {
      color: ${c.accent-green};
      border-color: ${c.accent-green-dim};
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(0, 255, 65, 0.08) 100%);
    }
    #lock:hover {
      border-color: ${c.accent-green};
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 25px ${c.accent-green}66,
        0 0 50px ${c.accent-green}33;
    }

    /* Logout - Eject */
    #logout {
      color: ${c.caution-yellow};
      border-color: rgba(255, 200, 0, 0.5);
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(255, 200, 0, 0.08) 100%);
    }
    #logout:hover {
      border-color: ${c.caution-yellow};
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 25px rgba(255, 200, 0, 0.4),
        0 0 50px rgba(255, 200, 0, 0.2);
    }

    /* Suspend - Standby power */
    #suspend {
      color: ${c.accent-amber};
      border-color: ${c.accent-amber-dim};
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(255, 158, 59, 0.08) 100%);
    }
    #suspend:hover {
      border-color: ${c.accent-amber};
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 25px ${c.accent-amber}66,
        0 0 50px ${c.accent-amber}33;
    }

    /* Hibernate - Deep standby */
    #hibernate {
      color: ${c.accent-amber-dim};
      border-color: rgba(180, 110, 40, 0.5);
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(180, 110, 40, 0.08) 100%);
    }
    #hibernate:hover {
      border-color: ${c.accent-amber-dim};
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 25px rgba(180, 110, 40, 0.4),
        0 0 50px rgba(180, 110, 40, 0.2);
    }

    /* Shutdown - Engine cut */
    #shutdown {
      color: ${c.warning-red};
      border-color: rgba(255, 56, 56, 0.6);
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(255, 56, 56, 0.12) 100%);
    }
    #shutdown:hover {
      border-color: ${c.warning-red};
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        rgba(255, 56, 56, 0.15) 50%,
        rgba(255, 56, 56, 0.25) 100%);
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 30px rgba(255, 56, 56, 0.5),
        0 0 60px rgba(255, 56, 56, 0.3);
    }

    /* Reboot - Engine restart */
    #reboot {
      color: ${c.info-blue};
      border-color: rgba(82, 139, 255, 0.5);
      background: linear-gradient(180deg,
        ${c.bg-tertiary} 0%,
        ${c.bg-secondary} 40%,
        rgba(82, 139, 255, 0.08) 100%);
    }
    #reboot:hover {
      border-color: ${c.info-blue};
      box-shadow:
        inset 0 1px 0 rgba(255, 255, 255, 0.1),
        0 0 25px rgba(82, 139, 255, 0.4),
        0 0 50px rgba(82, 139, 255, 0.2);
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
