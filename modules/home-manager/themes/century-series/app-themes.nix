# ~/nixos-config/modules/home-manager/themes/century-series/app-themes.nix
# Pure Nix file — import with: import ./app-themes.nix { inherit lib; }
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
{ lib, ... }:

with lib;

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

  mkBtopTheme = p: ''
    # Century Series Theme for btop
    # Cold War Aviation Cockpit Aesthetic

    # Main background
    theme[main_bg]="${p.bg-primary}"

    # Main text color
    theme[main_fg]="${p.text-primary}"

    # Title color for boxes
    theme[title]="${p.accent-amber}"

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="${p.accent-amber-glow}"

    # Background color of selected item in processes box
    theme[selected_bg]="${p.bg-secondary}"

    # Foreground color of selected item in processes box
    theme[selected_fg]="${p.accent-amber}"

    # Color of inactive/disabled text
    theme[inactive_fg]="${p.text-tertiary}"

    # Color of text appearing on top of graphs
    theme[graph_text]="${p.accent-green}"

    # Background color of the meter bar
    theme[meter_bg]="${p.border-primary}"

    # Misc colors for processes box including mini cpu graphs, subtle hierarchies, andடும்
    theme[proc_misc]="${p.accent-green-dim}"

    # CPU box outline color
    theme[cpu_box]="${p.border-primary}"

    # Memory/disks box outline color
    theme[mem_box]="${p.border-primary}"

    # Net up/down box outline color
    theme[net_box]="${p.border-primary}"

    # Processes box outline color
    theme[proc_box]="${p.border-primary}"

    # Box divider line and target box/boxes outline color on mouse hover
    theme[div_line]="${p.border-secondary}"

    # Temperature graph colors (green to red)
    theme[temp_start]="${p.accent-green}"
    theme[temp_mid]="${p.caution-yellow}"
    theme[temp_end]="${p.warning-red}"

    # CPU graph colors (green phosphor style)
    theme[cpu_start]="${p.accent-green-dim}"
    theme[cpu_mid]="${p.accent-green}"
    theme[cpu_end]="${p.accent-radar}"

    # Mem/Disk free meter (amber style)
    theme[free_start]="${p.accent-amber-dim}"
    theme[free_mid]="${p.accent-amber}"
    theme[free_end]="${p.accent-amber-glow}"

    # Mem/Disk cached meter
    theme[cached_start]="${p.info-blue}"
    theme[cached_mid]="${p.info-blue}"
    theme[cached_end]="${p.info-blue}"

    # Mem/Disk available meter
    theme[available_start]="${p.accent-green-dim}"
    theme[available_mid]="${p.accent-green}"
    theme[available_end]="${p.accent-green}"

    # Mem/Disk used meter (warning colors)
    theme[used_start]="${p.caution-yellow}"
    theme[used_mid]="${p.accent-amber}"
    theme[used_end]="${p.warning-red}"

    # Download graph colors
    theme[download_start]="${p.accent-green-dim}"
    theme[download_mid]="${p.accent-green}"
    theme[download_end]="${p.accent-radar}"

    # Upload graph colors
    theme[upload_start]="${p.accent-amber-dim}"
    theme[upload_mid]="${p.accent-amber}"
    theme[upload_end]="${p.accent-amber-glow}"

    # Process box color gradient for threads, memory, and cpu usage
    theme[process_start]="${p.accent-green-dim}"
    theme[process_mid]="${p.accent-amber}"
    theme[process_end]="${p.warning-red}"
  '';

  mkYaziTheme = p: ''
    # Century Series Theme for Yazi
    # Cold War Aviation Cockpit Aesthetic

    [manager]
    cwd = { fg = "${p.accent-amber}" }

    # Hovered item
    hovered = { fg = "${p.bg-primary}", bg = "${p.accent-amber}" }
    preview_hovered = { underline = true }

    # Find highlighting
    find_keyword = { fg = "${p.accent-radar}", bold = true }
    find_position = { fg = "${p.accent-green}", bg = "reset", bold = true }

    # Marker colors
    marker_copied = { fg = "${p.accent-green}", bg = "${p.accent-green}" }
    marker_cut = { fg = "${p.warning-red}", bg = "${p.warning-red}" }
    marker_marked = { fg = "${p.accent-amber}", bg = "${p.accent-amber}" }
    marker_selected = { fg = "${p.info-blue}", bg = "${p.info-blue}" }

    # Tab styling
    tab_active = { fg = "${p.bg-primary}", bg = "${p.accent-amber}" }
    tab_inactive = { fg = "${p.text-secondary}", bg = "${p.bg-secondary}" }
    tab_width = 1

    # Count indicators
    count_copied = { fg = "${p.bg-primary}", bg = "${p.accent-green}" }
    count_cut = { fg = "${p.bg-primary}", bg = "${p.warning-red}" }
    count_selected = { fg = "${p.bg-primary}", bg = "${p.info-blue}" }

    # Borders
    border_symbol = "│"
    border_style = { fg = "${p.border-primary}" }

    [status]
    separator_open = ""
    separator_close = ""
    separator_style = { fg = "${p.border-primary}", bg = "${p.bg-secondary}" }

    # Mode indicators
    mode_normal = { fg = "${p.bg-primary}", bg = "${p.accent-green}", bold = true }
    mode_select = { fg = "${p.bg-primary}", bg = "${p.accent-amber}", bold = true }
    mode_unset = { fg = "${p.bg-primary}", bg = "${p.warning-red}", bold = true }

    # Progress bar
    progress_label = { fg = "${p.text-primary}", bold = true }
    progress_normal = { fg = "${p.accent-amber}", bg = "${p.bg-secondary}" }
    progress_error = { fg = "${p.warning-red}", bg = "${p.bg-secondary}" }

    # Permissions
    permissions_t = { fg = "${p.accent-amber}" }
    permissions_r = { fg = "${p.accent-green}" }
    permissions_w = { fg = "${p.warning-red}" }
    permissions_x = { fg = "${p.caution-yellow}" }
    permissions_s = { fg = "${p.info-blue}" }

    [select]
    border = { fg = "${p.border-primary}" }
    active = { fg = "${p.accent-amber}", bold = true }
    inactive = { fg = "${p.text-secondary}" }

    [input]
    border = { fg = "${p.border-primary}" }
    title = { fg = "${p.accent-amber}" }
    value = { fg = "${p.text-primary}" }
    selected = { reversed = true }

    [completion]
    border = { fg = "${p.border-primary}" }
    active = { fg = "${p.bg-primary}", bg = "${p.accent-amber}" }
    inactive = { fg = "${p.text-secondary}" }

    [tasks]
    border = { fg = "${p.border-primary}" }
    title = { fg = "${p.accent-amber}" }
    hovered = { fg = "${p.bg-primary}", bg = "${p.accent-amber}" }

    [which]
    cols = 3
    mask = { bg = "${p.bg-secondary}" }
    cand = { fg = "${p.accent-green}" }
    rest = { fg = "${p.text-tertiary}" }
    desc = { fg = "${p.accent-amber}" }
    separator = " → "
    separator_style = { fg = "${p.border-primary}" }

    [help]
    on = { fg = "${p.accent-green}" }
    run = { fg = "${p.accent-amber}" }
    desc = { fg = "${p.text-secondary}" }
    hovered = { reversed = true, bold = true }
    footer = { fg = "${p.text-tertiary}", bg = "${p.bg-secondary}" }

    [notify]
    title_info = { fg = "${p.info-blue}" }
    title_warn = { fg = "${p.caution-yellow}" }
    title_error = { fg = "${p.warning-red}" }

    [filetype]
    rules = [
      # Directories
      { name = "*/", fg = "${p.accent-amber}", bold = true },

      # Executables
      { mime = "application/x-executable", fg = "${p.accent-green}" },
      { mime = "application/x-sharedlib", fg = "${p.accent-green-dim}" },

      # Archives
      { mime = "application/zip", fg = "${p.caution-yellow}" },
      { mime = "application/gzip", fg = "${p.caution-yellow}" },
      { mime = "application/x-tar", fg = "${p.caution-yellow}" },
      { mime = "application/x-bzip2", fg = "${p.caution-yellow}" },
      { mime = "application/x-xz", fg = "${p.caution-yellow}" },
      { mime = "application/x-7z-compressed", fg = "${p.caution-yellow}" },
      { mime = "application/x-rar", fg = "${p.caution-yellow}" },

      # Documents
      { mime = "application/pdf", fg = "${p.warning-red}" },
      { mime = "application/doc", fg = "${p.info-blue}" },
      { mime = "application/msword", fg = "${p.info-blue}" },

      # Images
      { mime = "image/*", fg = "${p.accent-amber-glow}" },

      # Videos
      { mime = "video/*", fg = "${p.accent-amber}" },

      # Audio
      { mime = "audio/*", fg = "${p.accent-green}" },

      # Text/Code
      { mime = "text/*", fg = "${p.text-primary}" },
      { name = "*.nix", fg = "${p.info-blue}" },
      { name = "*.rs", fg = "${p.accent-amber}" },
      { name = "*.py", fg = "${p.caution-yellow}" },
      { name = "*.js", fg = "${p.caution-yellow}" },
      { name = "*.ts", fg = "${p.info-blue}" },
      { name = "*.lua", fg = "${p.info-blue}" },
      { name = "*.sh", fg = "${p.accent-green}" },
      { name = "*.md", fg = "${p.text-secondary}" },
      { name = "*.json", fg = "${p.caution-yellow}" },
      { name = "*.toml", fg = "${p.accent-amber}" },
      { name = "*.yaml", fg = "${p.accent-amber}" },
      { name = "*.yml", fg = "${p.accent-amber}" },

      # Config files
      { name = "*.conf", fg = "${p.accent-green-dim}" },
      { name = "*.cfg", fg = "${p.accent-green-dim}" },
      { name = "*.ini", fg = "${p.accent-green-dim}" },

      # Git
      { name = ".git*/", fg = "${p.warning-red}" },
      { name = ".gitignore", fg = "${p.text-tertiary}" },

      # Fallback
      { name = "*", fg = "${p.text-primary}" },
    ]
  '';

  # imv takes 6-digit RRGGBB, optionally with a leading '#'. An 8-digit
  # RRGGBBAA value is NOT accepted: imv prints "Invalid hex color" and aborts
  # the whole config, so one bad colour makes imv exit 1 on every image.
  mkImvConfig = p:
    let hex = s: builtins.substring 1 6 s; in ''
    [options]
    background=${hex p.bg-primary}
    overlay_font=JetBrains Mono:11
    overlay_text_color=${hex p.accent-amber}
    overlay_background_color=${hex p.bg-secondary}
    overlay_background_alpha=cc
    overlay_position_bottom=false
    # There is no "full_pixel" in imv: initial_zoom is not an option at all and
    # scaling_mode only takes none/shrink/full/crop, so the old pair of
    # full_pixel lines was a second fatal config error hiding behind the colours.
    # shrink fits an oversized photo to the window without blowing up a small
    # one; nearest_neighbour keeps zoomed-in pixels crisp rather than smeared.
    scaling_mode=shrink
    upscaling_method=nearest_neighbour
    loop_input=true
    title_text=[imv] $current_file ($width x $height) [$scale% — $current/$total]
    '';

  # zathura: the settings attrset, which zathura.nix hands to home-manager
  # for the day file and night-mode.nix renders itself for the night one.
  # zathura has no reload and home-manager owns zathurarc, so the colours move
  # out of programs.zathura.options into an `include`d file that night mode
  # swaps. Non-colour settings stay in options below.
  zathuraOptions = {
    statusbar-h-padding = 8;
    statusbar-v-padding = 4;
    recolor = true;
    recolor-keephue = false;
  };

  mkZathuraColors = p: concatStringsSep "\n" (mapAttrsToList (k: v: ''set ${k} "${v}"'') {
    default-bg            = p.bg-primary;
    default-fg            = p.text-primary;
    statusbar-bg          = p.bg-secondary;
    statusbar-fg          = p.accent-amber;
    inputbar-bg           = p.bg-secondary;
    inputbar-fg           = p.accent-amber-glow;
    notification-bg       = p.bg-secondary;
    notification-fg       = p.text-primary;
    notification-error-bg = p.warning-red;
    notification-error-fg = p.bg-primary;
    notification-warning-bg = p.caution-yellow;
    notification-warning-fg = p.bg-primary;
    highlight-color         = p.accent-amber;
    highlight-active-color  = p.accent-amber-glow;
    completion-bg           = p.bg-secondary;
    completion-fg           = p.text-primary;
    completion-highlight-bg = p.accent-amber;
    completion-highlight-fg = p.bg-primary;
    index-bg                = p.bg-primary;
    index-fg                = p.text-primary;
    index-active-bg         = p.accent-amber;
    index-active-fg         = p.bg-primary;
    render-loading-bg       = p.bg-primary;
    render-loading-fg       = p.accent-green;
    recolor-lightcolor      = p.bg-primary;
    recolor-darkcolor       = p.text-primary;
  });

  # swaylock. home-manager only writes ~/.config/swaylock/config when settings
  # is non-empty (xdg.configFile ... = mkIf (cfg.settings != {})), so leaving it
  # empty hands the path over to night mode. The renderer in night-mode.nix
  # reproduces home-manager's own: bare key for true, key=value otherwise,
  # false omitted entirely.
  mkSwaylockSettings = p:
    let stripHash = s: builtins.substring 1 6 s; in {
    # ============================================
    # Century Series Cockpit Lock Screen
    # MFD Security Interface Aesthetic
    # ============================================

    # Background - Deep instrument panel black
    color = stripHash p.bg-primary;

    # Indicator ring - Cockpit gauge aesthetic
    indicator = true;
    indicator-radius = 120;
    indicator-thickness = 8;
    indicator-caps-lock = true;

    # Ring colors - MFD frame with amber/green accents
    ring-color = stripHash p.border-primary;
    ring-ver-color = stripHash p.accent-amber;
    ring-wrong-color = stripHash p.warning-red;
    ring-clear-color = stripHash p.accent-green;

    # Key highlight - Amber glow on keypress
    key-hl-color = stripHash p.accent-amber-glow;
    bs-hl-color = stripHash p.caution-yellow;

    # Separator - Gunmetal frame line
    separator-color = stripHash p.border-primary;

    # Inside ring colors - Panel backgrounds
    inside-color = stripHash p.bg-secondary;
    inside-ver-color = stripHash p.bg-secondary;
    inside-wrong-color = stripHash p.bg-secondary;
    inside-clear-color = stripHash p.bg-secondary;

    # Line between ring and inside
    line-color = stripHash p.border-primary;
    line-ver-color = stripHash p.accent-amber-dim;
    line-wrong-color = stripHash p.warning-red;
    line-clear-color = stripHash p.accent-green-dim;

    # Text colors - Instrument markings
    text-color = stripHash p.text-primary;
    text-ver-color = stripHash p.accent-amber;
    text-wrong-color = stripHash p.warning-red;
    text-clear-color = stripHash p.accent-green;
    text-caps-lock-color = stripHash p.caution-yellow;

    # Layout text - Military stencil style
    layout-text-color = stripHash p.text-secondary;

    # Font - Aviation instrument style
    font = "JetBrains Mono";
    font-size = 24;

    # Custom text - Aviation terminology.
    # No plain `text = ...`: swaylock-effects 1.7.0.0 (26.05) dropped the idle
    # -state --text option while keeping the per-state ones below, so
    # `--text=SECURE` reached getopt as an ambiguous prefix of --text-color /
    # --text-clear / --text-ver / --text-wrong. swaylock printed its usage and
    # exited 1, which silently broke BOTH Super+Escape and the idle lock.
    text-ver = "AUTHENTICATING";
    text-wrong = "ACCESS DENIED";
    text-clear = "CLEARED";
    text-caps-lock = "CAPS ACTIVE";

    # Effects (swaylock-effects features)
    clock = true;
    timestr = "%H:%M";
    datestr = "%Y-%m-%d";

    # Fade effect for cockpit power-up feel
    fade-in = 0.2;

    # Grace period - Allow immediate unlock briefly after lock
    grace = 2;
    grace-no-mouse = true;
    grace-no-touch = true;

    # Disable fingerprint indicator (not aviation-themed)
    disable-caps-lock-text = false;
    ignore-empty-password = true;
    show-failed-attempts = true;

    # Screenshot as background (shows current workspace dimmed)
    screenshots = true;

    # Dim and blur effect - Like looking through tinted canopy
    effect-blur = "8x5";
    effect-vignette = "0.5:0.5";
    effect-greyscale = false;

    # Scaling
    scaling = "fill";
  };

  # rofi colour variables, @import'ed by the theme in rofi.nix.
  mkRofiColors = p: ''
    * {
      bg-primary:     ${p.bg-primary};
      bg-secondary:   ${p.bg-secondary};
      bg-tertiary:    ${p.bg-tertiary};
      border-color:   ${p.border-primary};
      border-active:  ${p.border-active};
      accent-amber:   ${p.accent-amber};
      accent-green:   ${p.accent-green};
      text-primary:   ${p.text-primary};
      text-secondary: ${p.text-secondary};
      text-dark:      ${p.bg-primary};
      warning-red:    ${p.warning-red};
      metal:          ${p.metal};
      /* matched characters inside a selected row — was a literal #ffffff */
      highlight-match: ${p.rofi-match};
    }
  '';

  # wlogout annunciator tiles. The colour is baked into each SVG, so night
  # mode regenerates all twelve rather than restyling them — hence the
  # wlogoutIcons spec below, which night-mode.nix maps into swappable entries.
  mkSwitchSvg = { color, label, tile }: ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 180" width="560" height="720"
         text-rendering="geometricPrecision">
      <!-- Annunciator tile -->
      <rect x="8" y="18" width="124" height="144" rx="4"
            fill="${tile}" stroke="${color}" stroke-width="2" stroke-opacity="0.35"/>
      <!-- Label -->
      <text x="70" y="94" font-family="JetBrains Mono, monospace" font-size="14"
            font-weight="bold" fill="${color}" fill-opacity="0.55"
            text-anchor="middle" letter-spacing="1.5">${label}</text>
      <!-- Indicator bar (off) -->
      <rect x="52" y="122" width="36" height="3" rx="1" fill="${color}" fill-opacity="0.3"/>
    </svg>
  '';

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

  # name -> (palette key, label). The filenames stay colour-named because the
  # wlogout CSS references them; only their contents change at night.
  wlogoutIcons = [
    { file = "switch-green";     key = "accent-green";     label = "SECURE"; }
    { file = "switch-yellow";    key = "caution-yellow";   label = "EJECT"; }
    { file = "switch-amber";     key = "accent-amber";     label = "STANDBY"; }
    { file = "switch-amber-dim"; key = "accent-amber-dim"; label = "HIBERNATE"; }
    { file = "switch-red";       key = "warning-red";      label = "SHUTDOWN"; }
    { file = "switch-blue";      key = "info-blue";        label = "REBOOT"; }
  ];

  # GTK named colours for the wlogout stylesheet, @import'ed the same way
  # waybar's palette is.
  mkWlogoutColors = p:
    let c = (import ./colors.nix { }).rgbaOf p.bg-primary; in ''
      @define-color c_window rgba(${toString c.r}, ${toString c.g}, ${toString c.b}, 0.7);
    '';

  # Firefox/LibreWolf userChrome custom properties, @import'ed by
  # programs/browser/chrome/century-series.nix. Firefox reads it only at
  # startup, so a switch lands on the next browser launch.
  mkBrowserChromeColors = p: ''
    :root {
      --cs-bg-primary:       ${p.bg-primary};
      --cs-bg-secondary:     ${p.bg-secondary};
      --cs-bg-tertiary:      ${p.bg-tertiary};
      --cs-border-primary:   ${p.border-primary};
      --cs-border-secondary: ${p.border-secondary};
      --cs-accent-amber:     ${p.accent-amber};
      --cs-accent-amber-glow: ${p.accent-amber-glow};
      --cs-text-primary:     ${p.text-primary};
      --cs-text-secondary:   ${p.text-secondary};
    }
  '';
}
