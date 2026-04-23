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
  
  # Century Series wallpaper hierarchy - easy to customize
  wallpapers = {
    # Primary wallpapers (main displays)
    primary-horizontal = wallpaperDir + "/f-15-satellite.jpg";
    primary-vertical = wallpaperDir + "/carrier-top.jpg";
    
    # Secondary wallpapers (additional displays)  
    secondary-horizontal = wallpaperDir + "/f-4-cockpit.png";
    secondary-vertical = wallpaperDir + "/carrier-top.jpg";
    
    # Tertiary wallpapers (for systems with 3+ displays)
    tertiary-horizontal = wallpaperDir + "/f-4-cockpit.png";
    tertiary-vertical = wallpaperDir + "/carrier-top.jpg";
    
    # Default fallback
    fallback = wallpaperDir + "/f-15-satellite.jpg";
  };

  # Helper function to determine if a monitor is vertical (transform = 1 or 3)
  isVertical = monitor: 
    monitor.transform == "1" || monitor.transform == "3";

  # Helper function to categorize monitors by orientation and priority
  categorizeMonitors = monitors:
    let
      enabledMonitors = lib.filter (m: m.enabled) monitors;
      horizontalMonitors = lib.filter (m: !(isVertical m)) enabledMonitors;
      verticalMonitors = lib.filter (m: isVertical m) enabledMonitors;
    in {
      horizontal = horizontalMonitors;
      vertical = verticalMonitors;
      total = enabledMonitors;
    };

  # Function to assign wallpapers based on hierarchy
  assignWallpaper = monitor: index: orientation:
    let
      wallpaperKey = 
        if index == 0 then "primary-${orientation}"
        else if index == 1 then "secondary-${orientation}" 
        else "tertiary-${orientation}";
      
      wallpaper = wallpapers.${wallpaperKey} or wallpapers.fallback;
    in wallpaper;

  # Generate wallpaper assignments using the hierarchy system
  generateWallpaperAssignments = monitors:
    let
      categorized = categorizeMonitors monitors;
      
      # Create assignments for horizontal monitors
      horizontalAssignments = lib.imap0 (i: monitor:
        let
          identifierString = 
            if lib.strings.hasPrefix "desc:" monitor.identifier
            then monitor.identifier
            else if (lib.strings.hasInfix " " monitor.identifier) || (lib.strings.hasInfix "." monitor.identifier)
            then "desc:${monitor.identifier}"
            else monitor.identifier;
          wallpaper = assignWallpaper monitor i "horizontal";
        in "${identifierString},${wallpaper}"
      ) categorized.horizontal;

      # Create assignments for vertical monitors  
      verticalAssignments = lib.imap0 (i: monitor:
        let
          identifierString = 
            if lib.strings.hasPrefix "desc:" monitor.identifier
            then monitor.identifier
            else if (lib.strings.hasInfix " " monitor.identifier) || (lib.strings.hasInfix "." monitor.identifier)
            then "desc:${monitor.identifier}"
            else monitor.identifier;
          wallpaper = assignWallpaper monitor i "vertical";
        in "${identifierString},${wallpaper}"
      ) categorized.vertical;
    in
      horizontalAssignments ++ verticalAssignments;

  # Determine wallpaper assignments
  wallpaperAssignments = 
    if (lib.length customConfig.desktop.monitors) > 0
    then generateWallpaperAssignments customConfig.desktop.monitors
    else [ ",${wallpapers.fallback}" ]; # Single monitor fallback

  # Get all wallpapers needed for preloading
  wallpapersToPreload = lib.unique (lib.attrValues wallpapers);

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

  # GLSL header shared by both shaders
  crtGlslHeader = ''
    #version 320 es
    precision highp float;
    in vec2 v_texcoord;
    uniform sampler2D tex;
    out vec4 fragColor;

    float hash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }
  '';

  # Shared CRT effects body — sits inside main() after UV is established
  crtEffectsBody = ''
        // === CHROMATIC ABERRATION ===
        float aberration = 0.0006;
        float r = texture(tex, vec2(uv.x - aberration, uv.y)).r;
        float g = texture(tex, uv).g;
        float b = texture(tex, vec2(uv.x + aberration, uv.y)).b;
        vec4 color = vec4(r, g, b, 1.0);

        // === SCANLINES ===
        float scanline = mod(floor(gl_FragCoord.y), 2.0);
        color.rgb *= mix(0.62, 1.0, scanline);

        // === VIGNETTE ===
        float vigX = uv.x * (1.0 - uv.x) * 4.0;
        float vigY = uv.y * (1.0 - uv.y) * 4.0;
        float vignette = pow(vigX * vigY, 0.3);
        vignette = clamp(vignette, 0.6, 1.0);
        color.rgb *= vignette;

        // === DUAL-TONE PHOSPHOR ===
        float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        vec3 phosphorAmber = vec3(1.0, 0.62, 0.23);
        vec3 phosphorGreen = vec3(0.498, 0.855, 0.537);
        color.rgb = mix(color.rgb, color.rgb * phosphorAmber, luminance * 0.35);
        color.rgb += phosphorGreen * (1.0 - luminance) * 0.04;

        // === FILM GRAIN ===
        float grain = hash(uv);
        color.rgb += (grain - 0.5) * 0.025;

        fragColor = color;
  '';

  crtBarrelShader = ''
    ${crtGlslHeader}
    void main() {
        vec2 uv = v_texcoord;

        // === BARREL DISTORTION ===
        vec2 centered = uv * 2.0 - 1.0;
        float dist = dot(centered, centered);
        uv = (centered * (1.0 + 0.025 * dist)) * 0.5 + 0.5;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        ${crtEffectsBody}
    }
  '';

  crtToggleScript = ''
    #!/usr/bin/env bash
    BARREL_SHADER="${barrelShaderPath}"
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

    # Hyprpaper service for wallpaper management
    services.hyprpaper = {
      enable = true;
      settings = {
        preload = wallpapersToPreload;
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

        # screen_shader requires full repaints to avoid stale pixel artifacts
        debug = {
          damage_tracking = 0;
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

        # Layer rules for overlay applications (wlogout uses "gtk-layer-shell")
        layerrule = [
          "blur, gtk-layer-shell"
          "ignorezero, gtk-layer-shell"
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
