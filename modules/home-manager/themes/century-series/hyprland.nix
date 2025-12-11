# ~/nixos-config/modules/home-manager/themes/century-series/hyprland.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Wallpaper paths for Cold War aviation theme
  wallpaperDir = config.home.homeDirectory + "/.local/share/wallpapers";
  wallpaperF104 = wallpaperDir + "/f104-retro-future.jpg";
  wallpaperSoviet = wallpaperDir + "/soviet-retro-future.jpg";
  wallpaperConcorde = wallpaperDir + "/concorde-vertical-art.jpg";
  wallpaperHangar1 = wallpaperDir + "/future-aviation-hanger-1.jpg";

  # Monitor descriptions for hyprpaper (same as functional but used only for wallpaper assignment)
  monitorDescMainDell = "Dell Inc. DELL S2721HGF DZR2123";
  monitorDescLeftVirt = "Dell Inc. OptiPlex 7760 0x36419E0A";
  monitorDescRightVirt = "Samsung Electric Company S27R65x H4TW800293";
  monitorDescTV = "Hisense Electric Co. Ltd. 4Series43 0x00000278";

  # Border width configuration for MFD-style appearance
  mfdBorderSize = if centuryConfig.borderStyle or "mfd" == "mfd" then 3 else 2;

  # Get primary accent based on mode
  primaryAccent =
    if (centuryConfig.accentMode or "mixed") == "amber" then c.accent-amber
    else if (centuryConfig.accentMode or "mixed") == "green" then c.accent-green
    else c.accent-amber;  # Default to amber for mixed mode

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    # Wallpaper file linking for Cold War aviation theme
    home.file.".local/share/wallpapers/f104-retro-future.jpg".source = ../../../../assets/wallpapers/f104-retro-future.jpg;
    home.file.".local/share/wallpapers/soviet-retro-future.jpg".source = ../../../../assets/wallpapers/soviet-retro-future.jpg;
    home.file.".local/share/wallpapers/concorde-vertical-art.jpg".source = ../../../../assets/wallpapers/concorde-vertical-art.jpg;
    home.file.".local/share/wallpapers/future-aviation-hanger-1.jpg".source = ../../../../assets/wallpapers/future-aviation-hanger-1.jpg;

    # Hyprpaper service for wallpaper management
    services.hyprpaper = {
      enable = true;
      settings = {
        preload = [ wallpaperF104 wallpaperSoviet wallpaperConcorde wallpaperHangar1 ];
        wallpaper = [
          "desc:${monitorDescMainDell},${wallpaperF104}"           # F-104 on main monitor
          "desc:${monitorDescLeftVirt},${wallpaperConcorde}"       # Concorde on left (vertical)
          "desc:${monitorDescRightVirt},${wallpaperSoviet}"        # Soviet on right (vertical)
          "desc:${monitorDescTV},${wallpaperHangar1}"              # Hangar on TV
        ];
        ipc = false;
        splash = false;
      };
    };

    # Century Series Hyprland Theme Configuration
    wayland.windowManager.hyprland = {
      # No need for enable = true; here, as that's set in functional.nix
      # These settings will be merged with functional.nix

      settings = {
        # General theming - MFD bezel aesthetic
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = mfdBorderSize;

          # MFD-style borders: inactive windows have gunmetal bezel,
          # active windows have glowing amber/green accent
          "col.inactive_border" = "rgb(${removePrefix "#" c.border-primary})";
          "col.active_border" = "rgb(${removePrefix "#" primaryAccent}) rgb(${removePrefix "#" c.border-active}) 45deg";

          resize_on_border = true;
          extend_border_grab_area = 15;
        };

        # Decoration - Cockpit glass and metal materials
        decoration = {
          rounding = 0;  # Cockpit displays are rectangular

          # Dim inactive windows like non-active MFD panels
          dim_inactive = true;
          dim_strength = 0.15;

          # Blur for background - like looking through tinted cockpit glass
          blur = {
            enabled = true;
            size = 6;
            passes = 3;
            new_optimizations = true;
            ignore_opacity = true;
            xray = false;
            contrast = 1.1;
            brightness = 0.95;
          };
        };

        # Animations - Smooth but purposeful, like hydraulic actuators
        animations = {
          enabled = true;
          bezier = [
            "cockpit, 0.25, 0.1, 0.25, 1.0"  # Mechanical movement feel
            "hydraulic, 0.4, 0.0, 0.2, 1.0"  # Hydraulic actuator
          ];

          animation = [
            "windows, 1, 4, hydraulic, slide"
            "windowsOut, 1, 4, cockpit, slide"
            "border, 1, 8, cockpit"
            "borderangle, 1, 50, cockpit, loop"
            "fade, 1, 5, cockpit"
            "workspaces, 1, 4, hydraulic, slidevert"
          ];
        };

        # Input configuration
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
          accel_profile = "flat";  # Precise like flight controls
        };

        # Dwindle layout - organized like instrument panels
        dwindle = {
          pseudotile = true;
          preserve_split = true;
          smart_split = false;
          force_split = 2;  # Always split to right/bottom
        };

        # Master layout alternative
        master = {
          new_status = "master";
          orientation = "right";
        };

        # Theme-specific misc visual settings
        misc = {
          force_default_wallpaper = mkForce 0;  # Let hyprpaper handle wallpapers
        };

        # Window rules for specific applications
        windowrulev2 = [
          # Float and center dialogs like popup instruments
          "float, class:^(.*), title:^(.*)(dialog|Dialog|confirm|Confirm).*$"
          "center, class:^(.*), title:^(.*)(dialog|Dialog|confirm|Confirm).*$"

          # Terminal - phosphor green accent border
          "bordercolor rgb(${removePrefix "#" c.accent-green}) rgb(${removePrefix "#" c.accent-green-dim}) 45deg, class:^(kitty)$"

          # Browsers - amber accent border
          "bordercolor rgb(${removePrefix "#" c.accent-amber}) rgb(${removePrefix "#" c.accent-amber-dim}) 45deg, class:^(firefox|chromium|brave).*$"
        ];
      };

      # Environment variables for consistent theming
      extraConfig = ''
        # Toolkit theming
        env = QT_QPA_PLATFORMTHEME,qt5ct
        env = QT_STYLE_OVERRIDE,adwaita-dark
        env = GTK_THEME,Adwaita:dark

        # Cursor
        env = XCURSOR_SIZE,24

        # Session variables
        env = XDG_CURRENT_DESKTOP,Hyprland
        env = XDG_SESSION_TYPE,wayland
        env = XDG_SESSION_DESKTOP,Hyprland
      '';
    };

    # Enable Hyprland
    wayland.windowManager.hyprland.enable = true;
  };
}
