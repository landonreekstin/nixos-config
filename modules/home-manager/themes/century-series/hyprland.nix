# ~/nixos-config/modules/home-manager/themes/century-series/hyprland.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Wallpaper hierarchy + per-monitor assignment, shared with night-mode.nix
  # (which needs the night set for the awww crossfade).
  wallpaperSets = import ./wallpapers.nix {
    inherit lib customConfig;
    homeDir = config.home.homeDirectory;
  };
  wallpaperAssignments = wallpaperSets.dayAssignments;

  wallpaperEngine = customConfig.desktop.hyprland.wallpaperEngine;

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

  hasCkbNext = customConfig.hardware.peripherals.ckb-next.enable;
  ckbScripts = import ./ckb-scripts.nix { inherit pkgs; };

  barrelShaderPath = "${config.home.homeDirectory}/.config/hypr/shaders/crt-barrel.glsl";

  # The CRT screen shader now lives in crt-shader.nix as a function of the
  # palette, so night-mode.nix can generate one shader per ramp step. This is
  # the DAY shader at the stable path century-crt-toggle has always used.
  crtShaders = import ./crt-shader.nix { };
  crtBarrelShader = crtShaders.mkCrtBarrelShader c 1.0;

  crtToggleScript = ''
    #!/usr/bin/env bash
    # Turn the filter on with the shader for the CURRENT day/night phase.
    # night-mode.nix writes that path to ~/.cache/century-night-shader on every
    # ramp step and at login; the stable day shader is the fallback for when
    # night mode is disabled or has not run yet.
    BARREL_SHADER="${barrelShaderPath}"
    PHASE_SHADER="$HOME/.cache/century-night-shader"
    if [ -r "$PHASE_SHADER" ]; then
        CANDIDATE=$(cat "$PHASE_SHADER")
        [ -r "$CANDIDATE" ] && BARREL_SHADER="$CANDIDATE"
    fi
    CURRENT=$(hyprctl getoption decoration:screen_shader | grep "str:" | awk '{print $2}')
    if [ -z "$CURRENT" ] || [ "$CURRENT" = "[[EMPTY]]" ]; then
        hyprctl keyword decoration:screen_shader "$BARREL_SHADER"
        notify-send -t 1500 -i display "CRT Filter" "Phosphor display ONLINE"
    else
        hyprctl keyword decoration:screen_shader ""
        notify-send -t 1500 -i display "CRT Filter" "Phosphor display OFFLINE"
    fi
  '';

  crtBarsToggleScript = ''
    #!/usr/bin/env bash
    pkill -SIGUSR1 waybar
  '';

in {
  config = mkIf centurySeriesThemeCondition {
    home.file.".config/hypr/shaders/crt-barrel.glsl".text = crtBarrelShader;
    home.file.".local/bin/century-crt-toggle" = {
      text = crtToggleScript;
      executable = true;
    };
    home.file.".local/bin/century-bars-toggle" = {
      text = crtBarsToggleScript;
      executable = true;
    };


    # Wallpaper file linking for Cold War aviation theme
    home.file.".local/share/wallpapers/f-15-satellite.jpg".source = ../../../../assets/wallpapers/f-15-satellite.jpg;
    home.file.".local/share/wallpapers/f-4-cockpit.png".source = ../../../../assets/wallpapers/f-4-cockpit.png;
    home.file.".local/share/wallpapers/carrier-top.jpg".source = ../../../../assets/wallpapers/carrier-top.jpg;

    # Night-mission set
    home.file.".local/share/wallpapers/f-117-sunset.jpg".source = ../../../../assets/wallpapers/f-117-sunset.jpg;
    home.file.".local/share/wallpapers/cockpit-night.jpg".source = ../../../../assets/wallpapers/cockpit-night.jpg;
    home.file.".local/share/wallpapers/eurofighter-night-vertical.jpg".source = ../../../../assets/wallpapers/eurofighter-night-vertical.jpg;

    # Hyprpaper service for wallpaper management.
    # Only while hyprpaper is still the engine: night mode flips the default to
    # awww, which night-mode.nix drives directly (hyprpaper 0.8.x has no IPC, so
    # it could only be restarted, which blinks). Leaving this on under awww
    # would also start a second, competing wallpaper daemon.
    services.hyprpaper = mkIf (wallpaperEngine == "hyprpaper") {
      enable = true;
      settings = {
        wallpaper = wallpaperAssignments;
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
        # (pseudotile removed in Hyprland 0.55 — see functional.nix)
        dwindle = {
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

        # screen_shader requires full repaints to avoid stale pixel artifacts
        debug = {
          damage_tracking = 0;
        };

        # Window rules for specific applications
        # Hyprland 0.55 syntax: `<effect> <value>` pairs, matchers prefixed
        # `match:`. bordercolor was renamed to border_color.
        windowrule = [
          # Float and center dialogs like popup instruments
          "float true, match:class ^(.*), match:title ^(.*)(dialog|Dialog|confirm|Confirm).*$"
          "center true, match:class ^(.*), match:title ^(.*)(dialog|Dialog|confirm|Confirm).*$"

          # Browsers - amber accent border
          "border_color rgb(${removePrefix "#" c.accent-amber}) rgb(${removePrefix "#" c.accent-amber-dim}) 45deg, match:class ^(firefox|chromium|brave).*$"

        ];

        # Layer rules for overlay applications (wlogout uses "gtk-layer-shell").
        # ignorezero became ignore_alpha, which takes the threshold as its value —
        # 0 reproduces the old "ignore fully transparent pixels" behaviour.
        layerrule = [
          "blur true, match:namespace gtk-layer-shell"
          "ignore_alpha 0, match:namespace gtk-layer-shell"
        ];

        # Theme-specific keybinds
        bind = [
          # Toggle CRT phosphor filter on/off
          "SUPER CTRL, G, exec, ~/.local/bin/century-crt-toggle"
          # Toggle top/bottom bars — also applies barrel distortion if CRT is on
          "SUPER, F10, exec, ~/.local/bin/century-bars-toggle"
        ] ++ lib.optionals hasCkbNext [
          # Keyboard color cycle (RADAR → AMBER → RED → MIG → RADAR)
          # CTRL avoids conflict with SUPER+K (swapwindow up) in functional.nix
          "SUPER CTRL, K, exec, ${ckbScripts.colorCycleScript}"
          # Keyboard brightness: dim / brighten by 10%
          # CTRL+J/L avoids conflict with SUPER+SHIFT+K/J (resizeactive) in functional.nix
          "SUPER CTRL, J, exec, ${ckbScripts.brightnessScript} down"
          "SUPER CTRL, L, exec, ${ckbScripts.brightnessScript} up"
        ];
      };

      # Environment variables for consistent theming
      extraConfig = ''
        # Start CRT fullscreen watcher

        # Apply the correct day/night palette instantly at login (no ramp).
        # exec-once is additive in hyprlang, so this merges with the mkDefault
        # list in hyprland/functional.nix without the functional layer needing
        # to know this theme has a night mode.
        exec-once = century-night init

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
