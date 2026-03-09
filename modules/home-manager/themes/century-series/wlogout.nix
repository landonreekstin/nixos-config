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

  # SVG cockpit switch panel - realistic aircraft style
  mkSwitchSvg = { color, label }: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 180">
      <defs>
        <linearGradient id="panel" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" style="stop-color:#3a3a3a"/>
          <stop offset="50%" style="stop-color:#2a2a2a"/>
          <stop offset="100%" style="stop-color:#1a1a1a"/>
        </linearGradient>
        <linearGradient id="switchBody" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#4a4a4a"/>
          <stop offset="50%" style="stop-color:#333333"/>
          <stop offset="100%" style="stop-color:#222222"/>
        </linearGradient>
        <linearGradient id="switchTop" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" style="stop-color:#555"/>
          <stop offset="100%" style="stop-color:#333"/>
        </linearGradient>
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
        <filter id="inset">
          <feOffset dx="1" dy="1"/>
          <feGaussianBlur stdDeviation="1" result="shadow"/>
          <feComposite in="SourceGraphic" in2="shadow" operator="over"/>
        </filter>
      </defs>
      <!-- Panel background with screws -->
      <rect x="2" y="2" width="136" height="176" rx="4" fill="url(#panel)" stroke="#0a0a0a" stroke-width="2"/>
      <!-- Corner screws -->
      <circle cx="12" cy="12" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="128" cy="12" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="12" cy="168" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="128" cy="168" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <!-- Screw slots -->
      <line x1="10" y1="12" x2="14" y2="12" stroke="#111" stroke-width="1.5"/>
      <line x1="126" y1="12" x2="130" y2="12" stroke="#111" stroke-width="1.5"/>
      <line x1="10" y1="168" x2="14" y2="168" stroke="#111" stroke-width="1.5"/>
      <line x1="126" y1="168" x2="130" y2="168" stroke="#111" stroke-width="1.5"/>
      <!-- Switch housing/bezel -->
      <rect x="25" y="25" width="90" height="90" rx="6" fill="#1a1a1a" stroke="#0a0a0a" stroke-width="2"/>
      <rect x="30" y="30" width="80" height="80" rx="4" fill="url(#switchBody)" stroke="#333" stroke-width="1"/>
      <!-- Toggle switch base -->
      <ellipse cx="70" cy="70" rx="25" ry="20" fill="#222" stroke="#444" stroke-width="1"/>
      <!-- Toggle lever -->
      <rect x="62" y="45" width="16" height="35" rx="3" fill="url(#switchTop)" stroke="#555" stroke-width="1"/>
      <rect x="64" y="47" width="12" height="4" rx="1" fill="rgba(255,255,255,0.2)"/>
      <!-- Indicator light housing -->
      <circle cx="70" cy="95" r="8" fill="#111" stroke="#333" stroke-width="1"/>
      <!-- Indicator light (dim) -->
      <circle cx="70" cy="95" r="5" fill="${color}" opacity="0.4"/>
      <!-- Label plate -->
      <rect x="20" y="125" width="100" height="35" rx="2" fill="#111" stroke="#333" stroke-width="1"/>
      <rect x="22" y="127" width="96" height="31" rx="1" fill="#0a0a0a"/>
      <!-- Engraved label effect -->
      <text x="70" y="148" font-family="monospace" font-size="11" font-weight="bold" fill="${color}" text-anchor="middle" opacity="0.9">${label}</text>
    </svg>
  '';

  mkSwitchHoverSvg = { color, label }: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 180">
      <defs>
        <linearGradient id="panel" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" style="stop-color:#3a3a3a"/>
          <stop offset="50%" style="stop-color:#2a2a2a"/>
          <stop offset="100%" style="stop-color:#1a1a1a"/>
        </linearGradient>
        <linearGradient id="switchBody" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#5a5a5a"/>
          <stop offset="50%" style="stop-color:#444444"/>
          <stop offset="100%" style="stop-color:#333333"/>
        </linearGradient>
        <linearGradient id="switchTop" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" style="stop-color:#666"/>
          <stop offset="100%" style="stop-color:#444"/>
        </linearGradient>
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="4" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <!-- Panel background with screws -->
      <rect x="2" y="2" width="136" height="176" rx="4" fill="url(#panel)" stroke="#0a0a0a" stroke-width="2"/>
      <!-- Corner screws -->
      <circle cx="12" cy="12" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="128" cy="12" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="12" cy="168" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <circle cx="128" cy="168" r="4" fill="#222" stroke="#444" stroke-width="1"/>
      <!-- Screw slots -->
      <line x1="10" y1="12" x2="14" y2="12" stroke="#111" stroke-width="1.5"/>
      <line x1="126" y1="12" x2="130" y2="12" stroke="#111" stroke-width="1.5"/>
      <line x1="10" y1="168" x2="14" y2="168" stroke="#111" stroke-width="1.5"/>
      <line x1="126" y1="168" x2="130" y2="168" stroke="#111" stroke-width="1.5"/>
      <!-- Switch housing/bezel - highlighted -->
      <rect x="25" y="25" width="90" height="90" rx="6" fill="#1a1a1a" stroke="${color}" stroke-width="1" opacity="0.5"/>
      <rect x="30" y="30" width="80" height="80" rx="4" fill="url(#switchBody)" stroke="#444" stroke-width="1"/>
      <!-- Toggle switch base -->
      <ellipse cx="70" cy="70" rx="25" ry="20" fill="#2a2a2a" stroke="#555" stroke-width="1"/>
      <!-- Toggle lever - raised position -->
      <rect x="62" y="40" width="16" height="35" rx="3" fill="url(#switchTop)" stroke="#666" stroke-width="1"/>
      <rect x="64" y="42" width="12" height="4" rx="1" fill="rgba(255,255,255,0.3)"/>
      <!-- Indicator light housing -->
      <circle cx="70" cy="95" r="8" fill="#111" stroke="${color}" stroke-width="1" opacity="0.6"/>
      <!-- Indicator light (bright + glow) -->
      <circle cx="70" cy="95" r="6" fill="${color}" filter="url(#glow)" opacity="1"/>
      <!-- Light reflection -->
      <circle cx="68" cy="93" r="2" fill="rgba(255,255,255,0.5)"/>
      <!-- Label plate -->
      <rect x="20" y="125" width="100" height="35" rx="2" fill="#111" stroke="${color}" stroke-width="1" opacity="0.7"/>
      <rect x="22" y="127" width="96" height="31" rx="1" fill="#0a0a0a"/>
      <!-- Engraved label - glowing -->
      <text x="70" y="148" font-family="monospace" font-size="11" font-weight="bold" fill="${color}" text-anchor="middle" filter="url(#glow)">${label}</text>
    </svg>
  '';

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
    home.file = {
      ".config/wlogout/icons/switch-green.svg".text = mkSwitchSvg { color = "#7fda89"; label = "SECURE"; };
      ".config/wlogout/icons/switch-green-hover.svg".text = mkSwitchHoverSvg { color = "#7fda89"; label = "SECURE"; };
      ".config/wlogout/icons/switch-yellow.svg".text = mkSwitchSvg { color = "#ffb454"; label = "EJECT"; };
      ".config/wlogout/icons/switch-yellow-hover.svg".text = mkSwitchHoverSvg { color = "#ffb454"; label = "EJECT"; };
      ".config/wlogout/icons/switch-amber.svg".text = mkSwitchSvg { color = "#ff9e3b"; label = "STANDBY"; };
      ".config/wlogout/icons/switch-amber-hover.svg".text = mkSwitchHoverSvg { color = "#ff9e3b"; label = "STANDBY"; };
      ".config/wlogout/icons/switch-amber-dim.svg".text = mkSwitchSvg { color = "#cc7e2f"; label = "HIBERNATE"; };
      ".config/wlogout/icons/switch-amber-dim-hover.svg".text = mkSwitchHoverSvg { color = "#cc7e2f"; label = "HIBERNATE"; };
      ".config/wlogout/icons/switch-red.svg".text = mkSwitchSvg { color = "#ff3838"; label = "SHUTDOWN"; };
      ".config/wlogout/icons/switch-red-hover.svg".text = mkSwitchHoverSvg { color = "#ff3838"; label = "SHUTDOWN"; };
      ".config/wlogout/icons/switch-blue.svg".text = mkSwitchSvg { color = "#5ccfe6"; label = "REBOOT"; };
      ".config/wlogout/icons/switch-blue-hover.svg".text = mkSwitchHoverSvg { color = "#5ccfe6"; label = "REBOOT"; };
    };

    programs.wlogout = {
      enable = true;
      layout = wlogoutLayout;
      style = wlogoutStyle;
    };
  };
}
