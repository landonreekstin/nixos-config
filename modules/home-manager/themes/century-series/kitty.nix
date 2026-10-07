# ~/nixos-config/modules/home-manager/themes/century-series/kitty.nix
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors and configuration
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;
  centuryConfig = colorsModule.centuryConfig;

  # Colours live in app-themes.nix and are written to a generated
  # century-colors.conf that extraConfig below `include`s, so night mode can
  # swap that one file and SIGUSR1 kitty rather than needing a restart.
  # Non-colour settings stay in programs.kitty below.

  # Check if home-manager, Hyprland, and the Century Series theme are enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

in {
  config = mkIf centurySeriesThemeCondition {
    programs.kitty = {
      enable = true;

      # "JetBrainsMono Nerd Font", not plain "JetBrains Mono": the two are the
      # same typeface (Nerd Fonts patches the original glyphs unchanged) but only
      # the Nerd Font carries the icon glyphs that Claude Code, the shell prompt
      # and anything powerline-ish print. Asking for the plain family only worked
      # by fontconfig fallback, and kitty 0.44 -> 0.48 (nixos-26.05) tightened
      # that fallback, so those characters started rendering as tofu boxes.
      # nerd-fonts.jetbrains-mono is already installed by theme.nix.
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };

      settings = {
        # Window appearance - CRT monitor bezel
        window_padding_width = 8;
        window_border_width = "1.0pt";
        draw_minimal_borders = false;
        window_margin_width = 0;
        single_window_margin_width = 0;
        placement_strategy = "center";

        # Cursor - Blinking phosphor cursor
        cursor_shape = mkForce "block";
        cursor_blink_interval = mkForce 0.5;
        cursor_stop_blinking_after = 15.0;

        # URL styling - Data link highlighting
        url_style = "single";

        # Tab bar - Multi-display selector
        tab_bar_edge = mkForce "top";
        tab_bar_style = mkForce "separator";
        tab_bar_min_tabs = 1;
        tab_separator = " │ ";
        tab_title_template = "{index}: {title}";
        active_tab_font_style = "bold";
        inactive_tab_font_style = "normal";

        # Terminal bell - Audio warning system
        enable_audio_bell = false;
        visual_bell_duration = "0.1";

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

        # Marks - Reference markers like bearing indicators
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
        # Day/night palette. The ONLY runtime-swapped piece of kitty config:
        # night-mode.nix rewrites this file and sends SIGUSR1, which makes kitty
        # re-read its config in place. kitty resolves a relative include against
        # the including file — a /nix/store path here — so this must be
        # absolute. night-mode.nix guarantees the file exists in home.activation.
        include ${config.home.homeDirectory}/.config/kitty/century-colors.conf

        # Undercurl style for errors - Warning indicators
        undercurl_style thick-sparse

        # Shell integration
        shell_integration enabled

        # Clipboard
        clipboard_control write-clipboard write-primary read-clipboard read-primary

        # Advanced settings
        allow_remote_control yes
        listen_on unix:/tmp/kitty-{kitty_pid}

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
