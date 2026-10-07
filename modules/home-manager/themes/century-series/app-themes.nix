# ~/nixos-config/modules/home-manager/themes/century-series/app-themes.nix
# Pure Nix file — import with: import ./app-themes.nix { }
#
# Per-application colour files, each a function of the palette, so night-mode.nix
# can build a night variant of every one from the same source the day module
# uses. Kept here rather than in each app's module because both that module and
# the switcher need them — same reason colors.nix, crt-shader.nix and
# wallpapers.nix are pure files.
#
# These apps read their config only at launch (kitty is the exception: SIGUSR1
# makes it re-read in place), so night mode swaps the file and anything already
# open keeps the old palette until it restarts.
{ ... }:

{
  mkKittyColors = p: ''
    # century-series terminal colours — GENERATED, swapped by night mode.
    # Edit colors.nix, not this file.

    # CRT screen
    background            ${p.bg-primary}
    foreground            ${p.term-fg}
    selection_background  ${p.term-fg-dim}
    selection_foreground  ${p.bg-primary}

    # Window + tab chrome
    active_border_color     ${p.term-fg}
    inactive_border_color   ${p.border-primary}
    active_tab_foreground   ${p.bg-primary}
    active_tab_background   ${p.term-fg}
    inactive_tab_foreground ${p.text-secondary}
    inactive_tab_background ${p.bg-secondary}
    tab_bar_background      ${p.bg-tertiary}

    # Cursor + links
    cursor            ${p.term-fg}
    cursor_text_color ${p.bg-primary}
    url_color         ${p.info-blue}
    visual_bell_color ${p.warning-red}

    # ANSI
    color0  ${p.bg-primary}
    color1  ${p.warning-red}
    color2  ${p.term-green}
    color3  ${p.accent-amber-glow}
    color4  ${p.info-blue}
    color5  ${p.term-magenta}
    color6  ${p.term-cyan}
    color7  ${p.text-primary}
    color8  ${p.text-tertiary}
    color9  ${p.term-bright-red}
    color10 ${p.term-bright-green}
    color11 ${p.caution-yellow}
    color12 ${p.term-bright-blue}
    color13 ${p.term-bright-magenta}
    color14 ${p.term-bright-cyan}
    color15 ${p.term-bright-white}

    # Marks — reference markers like bearing indicators
    mark1_foreground ${p.bg-primary}
    mark1_background ${p.accent-amber}
    mark2_foreground ${p.bg-primary}
    mark2_background ${p.accent-green}
    mark3_foreground ${p.bg-primary}
    mark3_background ${p.info-blue}
  '';

  # Shell prompt. Every colour was a literal in bash.nix; all eight mapped
  # onto existing palette keys, so the day output is unchanged.
  mkStarshipToml = p: ''
    "$schema" = 'https://starship.rs/config-schema.json'

    # Two-line prompt:
    #   [▶ hostname ▸ user ▶][▶ directory ▶] branch status  nix  duration
    #   ❯
    format = """
    \n[](fg:${p.border-primary})\
    $hostname\
    $username\
    [](fg:${p.border-primary} bg:${p.bg-tertiary})\
    $directory\
    [](fg:${p.bg-tertiary})\
    $git_branch\
    $git_status\
    $nix_shell\
    $cmd_duration\
    $line_break\
    $character"""

    # ── Segment 1: host + user on gunmetal background ───────────────────────── #

    [hostname]
    format = '[ $hostname ▸](bg:${p.border-primary} fg:${p.accent-amber-dim})'
    ssh_only = false

    [username]
    format = '[ $user ](bg:${p.border-primary} fg:${p.accent-amber})'
    show_always = true

    # ── Segment 2: directory on dark panel background ────────────────────────── #

    [directory]
    format = '[ $path$read_only](bg:${p.bg-tertiary} fg:${p.accent-green}) '
    truncation_length = 3
    truncate_to_repo = true
    read_only = ' '
    read_only_style = 'fg:${p.warning-red} bg:${p.bg-tertiary}'

    # ── Git info: plain amber text after the segment ─────────────────────────── #

    [git_branch]
    format = '[ $symbol$branch ](fg:${p.accent-amber})'
    symbol = ' '

    [git_status]
    format = '[$all_status$ahead_behind ](fg:${p.accent-amber-dim})'
    staged    = '●'
    modified  = '✦'
    untracked = '+'
    deleted   = '✗'
    conflicted = '!'
    ahead     = '⇡''${count}'
    behind    = '⇣''${count}'
    diverged  = '⇕⇡''${ahead_count}⇣''${behind_count}'

    # ── Nix shell indicator ──────────────────────────────────────────────────── #

    [nix_shell]
    format = '[❄ $name ](fg:${p.info-blue})'
    heuristic = true

    # ── Command duration (shows for slow commands) ───────────────────────────── #

    [cmd_duration]
    format = '[⏱ $duration ](fg:${p.text-secondary})'
    min_time = 2000

    # ── Prompt character ─────────────────────────────────────────────────────── #

    [character]
    success_symbol = '[❯](bold fg:${p.accent-amber})'
    error_symbol   = '[❯](bold fg:${p.warning-red})'
  '';

  # Notifications. dunst is special: dunstctl reload takes a CONFIG PATH, so
  # night mode never replaces the live file — it just points dunst at a
  # different store path. Hence this returns the settings attrset, which
  # dunst.nix hands straight to services.dunst.
  mkDunstSettings = p: {
        global = {
          # Display positioning - Top right like warning light panel
          monitor = 0;
          follow = "mouse";
          origin = "top-right";
          offset = "12x48";  # Below waybar

          # Notification window - Warning light bezel
          width = "(200, 400)";
          height = 300;
          notification_limit = 5;

          # Progress bar - Like fuel/hydraulic gauges
          progress_bar = true;
          progress_bar_height = 10;
          progress_bar_frame_width = 1;
          progress_bar_min_width = 200;
          progress_bar_max_width = 400;

          # Appearance - Cockpit warning panel
          gap_size = 6;
          padding = 12;
          horizontal_padding = 12;
          text_icon_padding = 12;
          frame_width = 2;
          separator_height = 2;
          separator_color = "frame";
          corner_radius = 0;  # Rectangular like warning lights
          transparency = 5;

          # Typography - Military stencil style
          font = "JetBrains Mono Bold 10";
          line_height = 0;
          markup = "full";
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          vertical_alignment = "center";
          show_age_threshold = 60;
          word_wrap = true;
          ellipsize = "middle";
          ignore_newline = false;
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = true;

          # Icons - System status indicators
          icon_position = "left";
          min_icon_size = 24;
          max_icon_size = 48;
          icon_theme = "Papirus-Dark";
          enable_recursive_icon_lookup = true;

          # Interaction - Quick acknowledgment like button press
          mouse_left_click = "do_action, close_current";
          mouse_middle_click = "close_current";
          mouse_right_click = "close_all";

          # Timing - Warning light persistence
          idle_threshold = 120;
          sticky_history = true;
          history_length = 20;

          # Wayland specific
          layer = "overlay";
          force_xwayland = false;
        };

        # Urgency: Low - Advisory/Informational (Blue)
        urgency_low = {
          background = p.bg-secondary;
          foreground = p.info-blue;
          frame_color = p.info-blue;
          highlight = p.info-blue;
          timeout = 5;
        };

        # Urgency: Normal - Caution (Amber)
        urgency_normal = {
          background = p.bg-secondary;
          foreground = p.accent-amber;
          frame_color = p.accent-amber;
          highlight = p.accent-amber;
          timeout = 8;
        };

        # Urgency: Critical - Warning/Master Caution (Red)
        urgency_critical = {
          background = p.bg-primary;
          foreground = p.warning-red;
          frame_color = p.warning-red;
          highlight = p.warning-red;
          timeout = 0;  # Requires acknowledgment
        };

        # Custom rules for specific notification types

        # Volume notifications - Audio system
        volume = {
          appname = "volume";
          urgency = "low";
          background = p.bg-secondary;
          foreground = p.accent-amber;
          frame_color = p.accent-amber-dim;
          format = "<b>VOL</b> %b";
          timeout = 2;
        };

        # Brightness notifications - Display brightness
        brightness = {
          appname = "brightness";
          urgency = "low";
          background = p.bg-secondary;
          foreground = p.accent-green;
          frame_color = p.accent-green-dim;
          format = "<b>BRT</b> %b";
          timeout = 2;
        };

        # Battery notifications - Electrical system warnings
        battery_low = {
          appname = "battery";
          urgency = "critical";
          background = p.bg-primary;
          foreground = p.warning-red;
          frame_color = p.warning-red;
          format = "<b>⚠ BATTERY LOW</b>\\n%b";
        };

        battery_critical = {
          appname = "battery";
          summary = "*critical*";
          urgency = "critical";
          background = p.bg-primary;
          foreground = p.warning-red;
          frame_color = p.warning-red;
          format = "<b>⚠ BATTERY CRITICAL</b>\\n%b";
        };

        # Network notifications - Data link status
        network = {
          appname = "network";
          urgency = "low";
          background = p.bg-secondary;
          foreground = p.accent-green;
          frame_color = p.accent-green;
          format = "<b>LINK</b> %b";
          timeout = 4;
        };

        # System updates - Maintenance advisory
        updates = {
          appname = "update";
          urgency = "normal";
          background = p.bg-secondary;
          foreground = p.caution-yellow;
          frame_color = p.caution-yellow;
          format = "<b>SYS UPDATE</b>\\n%b";
        };

        # Screenshot notifications - Capture confirmation
        screenshot = {
          appname = "screenshot";
          urgency = "low";
          background = p.bg-secondary;
          foreground = p.accent-green;
          frame_color = p.accent-green;
          format = "<b>CAPTURE</b> %b";
          timeout = 3;
        };
  };
}
