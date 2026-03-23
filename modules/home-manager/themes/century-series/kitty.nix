# ~/nixos-config/modules/home-manager/themes/century-series/kitty.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Primary phosphor color based on accent mode
  phosphorColor =
    if (centuryConfig.accentMode or "mixed") == "amber" then c.accent-amber
    else if (centuryConfig.accentMode or "mixed") == "green" then c.accent-green
    else c.accent-green;  # Default to green for mixed (traditional CRT)

  phosphorDim =
    if (centuryConfig.accentMode or "mixed") == "amber" then c.accent-amber-dim
    else if (centuryConfig.accentMode or "mixed") == "green" then c.accent-green-dim
    else c.accent-green-dim;

  # CRT shader - Full retro effects
  # Includes scanlines, curvature, chromatic aberration, vignetting, and flicker
  crtShader = ''
    #version 330 core

    in vec2 fragCoord;
    out vec4 fragColor;

    uniform sampler2D text;
    uniform vec2 dimensions;
    uniform float time;

    // Effect intensity controls
    const float SCANLINE_INTENSITY = 0.15;
    const float CURVATURE_AMOUNT = 0.03;
    const float CHROMATIC_AMOUNT = 0.002;
    const float VIGNETTE_INTENSITY = 0.25;
    const float FLICKER_INTENSITY = 0.02;
    const float BLOOM_INTENSITY = 0.08;

    // Apply barrel distortion for CRT curvature
    vec2 curveUV(vec2 uv) {
        uv = uv * 2.0 - 1.0;
        vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
        uv = uv + uv * offset * offset * CURVATURE_AMOUNT * 10.0;
        uv = uv * 0.5 + 0.5;
        return uv;
    }

    // Chromatic aberration - RGB channel separation
    vec3 chromaticAberration(vec2 uv) {
        vec2 center = uv - 0.5;
        float dist = length(center);

        vec2 redOffset = uv + center * dist * CHROMATIC_AMOUNT;
        vec2 greenOffset = uv;
        vec2 blueOffset = uv - center * dist * CHROMATIC_AMOUNT;

        float r = texture(text, redOffset).r;
        float g = texture(text, greenOffset).g;
        float b = texture(text, blueOffset).b;

        return vec3(r, g, b);
    }

    // Scanline effect
    float scanline(vec2 uv) {
        float scanlineCount = dimensions.y * 0.75;
        float scanlinePhase = sin(uv.y * scanlineCount * 3.14159 * 2.0);
        return 1.0 - SCANLINE_INTENSITY * (0.5 + 0.5 * scanlinePhase);
    }

    // Vignette - darker edges
    float vignette(vec2 uv) {
        vec2 center = uv - 0.5;
        float dist = length(center);
        return 1.0 - dist * dist * VIGNETTE_INTENSITY * 4.0;
    }

    // Phosphor flicker simulation
    float flicker() {
        float noise = fract(sin(time * 12.9898) * 43758.5453);
        return 1.0 - FLICKER_INTENSITY * (0.5 + 0.5 * noise);
    }

    // Simple bloom approximation
    vec3 bloom(vec2 uv, vec3 color) {
        vec3 bloomColor = vec3(0.0);
        float blurSize = 1.0 / min(dimensions.x, dimensions.y);

        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                vec2 offset = vec2(float(x), float(y)) * blurSize * 2.0;
                bloomColor += texture(text, uv + offset).rgb;
            }
        }
        bloomColor /= 25.0;

        return color + bloomColor * BLOOM_INTENSITY;
    }

    void main() {
        vec2 uv = fragCoord / dimensions;

        // Apply CRT curvature
        vec2 curvedUV = curveUV(uv);

        // Check if we're outside the curved screen area
        if (curvedUV.x < 0.0 || curvedUV.x > 1.0 || curvedUV.y < 0.0 || curvedUV.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        // Get base color with chromatic aberration
        vec3 color = chromaticAberration(curvedUV);

        // Apply bloom for phosphor glow
        color = bloom(curvedUV, color);

        // Apply scanlines
        color *= scanline(curvedUV);

        // Apply vignette
        color *= vignette(curvedUV);

        // Apply flicker
        color *= flicker();

        // Subtle green/amber phosphor tint based on brightness
        float luminance = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 phosphorTint = vec3(0.9, 1.0, 0.85);  // Slight green phosphor cast
        color = mix(color, color * phosphorTint, luminance * 0.1);

        fragColor = vec4(color, 1.0);
    }
  '';

  # Terminal color scheme - Phosphor CRT aesthetic
  # Colors adapted to look like glowing phosphor on dark screen
  termColors = {
    # Standard colors - phosphor variations
    black = c.bg-primary;
    red = c.warning-red;
    green = if (centuryConfig.accentMode or "mixed") == "amber" then c.caution-yellow else c.accent-radar;
    yellow = c.accent-amber-glow;
    blue = c.info-blue;
    magenta = "#a277ff";  # Slight purple tint for magenta
    cyan = "#73daca";     # Cyan with phosphor feel
    white = c.text-primary;

    # Bright colors - glowing intensified
    bright-black = c.text-tertiary;
    bright-red = "#ff6b6b";
    bright-green = if (centuryConfig.accentMode or "mixed") == "amber" then c.accent-amber else c.accent-radar;
    bright-yellow = c.caution-yellow;
    bright-blue = "#89ddff";
    bright-magenta = "#c792ea";
    bright-cyan = "#80cbc4";
    bright-white = "#ffffff";
  };

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    # Place the CRT shader in kitty's config directory
    xdg.configFile."kitty/crt-shader.glsl".text = crtShader;

    programs.kitty = {
      enable = true;

      font = {
        name = "JetBrains Mono";
        size = 11;
      };

      settings = {
        # CRT shader for full retro effect
        shader = "${config.xdg.configHome}/kitty/crt-shader.glsl";

        # Window appearance - CRT monitor bezel
        window_padding_width = 8;
        window_border_width = "1.0pt";
        draw_minimal_borders = false;
        window_margin_width = 0;
        single_window_margin_width = 0;
        placement_strategy = "center";

        # Active/inactive border colors - Powered/unpowered monitor
        active_border_color = phosphorColor;
        inactive_border_color = c.border-primary;

        # Background and foreground - CRT screen
        background = c.bg-primary;
        foreground = phosphorColor;
        selection_background = phosphorDim;
        selection_foreground = c.bg-primary;

        # Cursor - Blinking phosphor cursor
        cursor = phosphorColor;
        cursor_text_color = c.bg-primary;
        cursor_shape = mkForce "block";
        cursor_blink_interval = mkForce 0.5;
        cursor_stop_blinking_after = 15.0;

        # URL styling - Data link highlighting
        url_color = c.info-blue;
        url_style = "single";

        # Tab bar - Multi-display selector
        tab_bar_edge = mkForce "top";
        tab_bar_style = mkForce "separator";
        tab_bar_min_tabs = 1;
        tab_separator = " │ ";
        tab_title_template = "{index}: {title}";
        active_tab_foreground = c.bg-primary;
        active_tab_background = phosphorColor;
        active_tab_font_style = "bold";
        inactive_tab_foreground = c.text-secondary;
        inactive_tab_background = c.bg-secondary;
        inactive_tab_font_style = "normal";
        tab_bar_background = c.bg-tertiary;

        # Terminal bell - Audio warning system
        enable_audio_bell = false;
        visual_bell_duration = "0.1";
        visual_bell_color = c.warning-red;

        # Performance - CRT phosphor persistence simulation
        repaint_delay = 10;
        input_delay = 3;
        sync_to_monitor = true;

        # Advanced - Slight glow effect
        background_opacity = "0.95";
        background_blur = 0;
        dim_opacity = "0.75";

        # Scrollback
        scrollback_lines = mkForce 10000;
        scrollback_pager_history_size = 10;

        # Mouse
        mouse_hide_wait = 3;
        copy_on_select = "clipboard";
        strip_trailing_spaces = "smart";

        # Terminal colors
        color0 = termColors.black;
        color1 = termColors.red;
        color2 = termColors.green;
        color3 = termColors.yellow;
        color4 = termColors.blue;
        color5 = termColors.magenta;
        color6 = termColors.cyan;
        color7 = termColors.white;
        color8 = termColors.bright-black;
        color9 = termColors.bright-red;
        color10 = termColors.bright-green;
        color11 = termColors.bright-yellow;
        color12 = termColors.bright-blue;
        color13 = termColors.bright-magenta;
        color14 = termColors.bright-cyan;
        color15 = termColors.bright-white;

        # Marks - Reference markers like bearing indicators
        mark1_foreground = c.bg-primary;
        mark1_background = c.accent-amber;
        mark2_foreground = c.bg-primary;
        mark2_background = c.accent-green;
        mark3_foreground = c.bg-primary;
        mark3_background = c.info-blue;
      };

      # Keybindings - Cockpit control style
      keybindings = {
        # Tab management - Display switching
        "ctrl+shift+t" = "new_tab";
        "ctrl+shift+w" = "close_tab";
        "ctrl+shift+right" = "next_tab";
        "ctrl+shift+left" = "previous_tab";
        "ctrl+shift+." = "move_tab_forward";
        "ctrl+shift+," = "move_tab_backward";

        # Window management
        "ctrl+shift+enter" = "new_window";
        "ctrl+shift+n" = "new_os_window";

        # Scrollback
        "ctrl+shift+h" = "show_scrollback";
        "ctrl+shift+up" = "scroll_line_up";
        "ctrl+shift+down" = "scroll_line_down";
        "ctrl+shift+page_up" = "scroll_page_up";
        "ctrl+shift+page_down" = "scroll_page_down";
        "ctrl+shift+home" = "scroll_home";
        "ctrl+shift+end" = "scroll_end";

        # Font size - Display brightness
        "ctrl+shift+equal" = "change_font_size all +1.0";
        "ctrl+shift+minus" = "change_font_size all -1.0";
        "ctrl+shift+backspace" = "change_font_size all 0";
      };

      # Additional config for CRT glow effect
      extraConfig = ''
        # Additional phosphor glow settings

        # Undercurl style for errors - Warning indicators
        undercurl_style thick-sparse

        # Shell integration
        shell_integration enabled

        # Clipboard
        clipboard_control write-clipboard write-primary read-clipboard read-primary

        # Advanced settings
        allow_remote_control yes
        listen_on unix:/tmp/kitty

        # Startup session
        startup_session none

        # OS specific tweaks
        linux_display_server auto

        # Performance tuning for smooth phosphor effect
        wayland_enable_ime no
      '';
    };
  };
}
