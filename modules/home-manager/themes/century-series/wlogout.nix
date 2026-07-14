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
  mkSwitchSvg = { color, label }: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 180" width="560" height="720"
         text-rendering="geometricPrecision">
      <!-- Annunciator tile -->
      <rect x="8" y="18" width="124" height="144" rx="4"
            fill="#0d1219" stroke="${color}" stroke-width="2" stroke-opacity="0.35"/>
      <!-- Label -->
      <text x="70" y="94" font-family="JetBrains Mono, monospace" font-size="14"
            font-weight="bold" fill="${color}" fill-opacity="0.55"
            text-anchor="middle" letter-spacing="1.5">${label}</text>
      <!-- Indicator bar (off) -->
      <rect x="52" y="122" width="36" height="3" rx="1" fill="${color}" fill-opacity="0.3"/>
    </svg>
  '';

  # Flat annunciator tile - lit / glowing hover state
  mkSwitchHoverSvg = { color, label }: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 180" width="560" height="720"
         text-rendering="geometricPrecision">
      <defs>
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.5" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <!-- Backlit inner wash -->
      <rect x="8" y="18" width="124" height="144" rx="4" fill="${color}" fill-opacity="0.08"/>
      <!-- Annunciator tile - glowing border -->
      <rect x="8" y="18" width="124" height="144" rx="4"
            fill="none" stroke="${color}" stroke-width="2" filter="url(#glow)"/>
      <!-- Label - lit -->
      <text x="70" y="94" font-family="JetBrains Mono, monospace" font-size="14"
            font-weight="bold" fill="${color}" text-anchor="middle"
            letter-spacing="1.5" filter="url(#glow)">${label}</text>
      <!-- Indicator bar (lit + glow) -->
      <rect x="48" y="121" width="44" height="4" rx="1" fill="${color}" filter="url(#glow)"/>
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
