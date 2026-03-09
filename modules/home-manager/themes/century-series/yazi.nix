# ~/nixos-config/modules/home-manager/themes/century-series/yazi.nix
# Century Series theme for yazi - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if century-series theme is enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # Yazi theme TOML
  yaziTheme = ''
    # Century Series Theme for Yazi
    # Cold War Aviation Cockpit Aesthetic

    [manager]
    cwd = { fg = "${c.accent-amber}" }

    # Hovered item
    hovered = { fg = "${c.bg-primary}", bg = "${c.accent-amber}" }
    preview_hovered = { underline = true }

    # Find highlighting
    find_keyword = { fg = "${c.accent-radar}", bold = true }
    find_position = { fg = "${c.accent-green}", bg = "reset", bold = true }

    # Marker colors
    marker_copied = { fg = "${c.accent-green}", bg = "${c.accent-green}" }
    marker_cut = { fg = "${c.warning-red}", bg = "${c.warning-red}" }
    marker_marked = { fg = "${c.accent-amber}", bg = "${c.accent-amber}" }
    marker_selected = { fg = "${c.info-blue}", bg = "${c.info-blue}" }

    # Tab styling
    tab_active = { fg = "${c.bg-primary}", bg = "${c.accent-amber}" }
    tab_inactive = { fg = "${c.text-secondary}", bg = "${c.bg-secondary}" }
    tab_width = 1

    # Count indicators
    count_copied = { fg = "${c.bg-primary}", bg = "${c.accent-green}" }
    count_cut = { fg = "${c.bg-primary}", bg = "${c.warning-red}" }
    count_selected = { fg = "${c.bg-primary}", bg = "${c.info-blue}" }

    # Borders
    border_symbol = "│"
    border_style = { fg = "${c.border-primary}" }

    [status]
    separator_open = ""
    separator_close = ""
    separator_style = { fg = "${c.border-primary}", bg = "${c.bg-secondary}" }

    # Mode indicators
    mode_normal = { fg = "${c.bg-primary}", bg = "${c.accent-green}", bold = true }
    mode_select = { fg = "${c.bg-primary}", bg = "${c.accent-amber}", bold = true }
    mode_unset = { fg = "${c.bg-primary}", bg = "${c.warning-red}", bold = true }

    # Progress bar
    progress_label = { fg = "${c.text-primary}", bold = true }
    progress_normal = { fg = "${c.accent-amber}", bg = "${c.bg-secondary}" }
    progress_error = { fg = "${c.warning-red}", bg = "${c.bg-secondary}" }

    # Permissions
    permissions_t = { fg = "${c.accent-amber}" }
    permissions_r = { fg = "${c.accent-green}" }
    permissions_w = { fg = "${c.warning-red}" }
    permissions_x = { fg = "${c.caution-yellow}" }
    permissions_s = { fg = "${c.info-blue}" }

    [select]
    border = { fg = "${c.border-primary}" }
    active = { fg = "${c.accent-amber}", bold = true }
    inactive = { fg = "${c.text-secondary}" }

    [input]
    border = { fg = "${c.border-primary}" }
    title = { fg = "${c.accent-amber}" }
    value = { fg = "${c.text-primary}" }
    selected = { reversed = true }

    [completion]
    border = { fg = "${c.border-primary}" }
    active = { fg = "${c.bg-primary}", bg = "${c.accent-amber}" }
    inactive = { fg = "${c.text-secondary}" }

    [tasks]
    border = { fg = "${c.border-primary}" }
    title = { fg = "${c.accent-amber}" }
    hovered = { fg = "${c.bg-primary}", bg = "${c.accent-amber}" }

    [which]
    cols = 3
    mask = { bg = "${c.bg-secondary}" }
    cand = { fg = "${c.accent-green}" }
    rest = { fg = "${c.text-tertiary}" }
    desc = { fg = "${c.accent-amber}" }
    separator = " → "
    separator_style = { fg = "${c.border-primary}" }

    [help]
    on = { fg = "${c.accent-green}" }
    run = { fg = "${c.accent-amber}" }
    desc = { fg = "${c.text-secondary}" }
    hovered = { reversed = true, bold = true }
    footer = { fg = "${c.text-tertiary}", bg = "${c.bg-secondary}" }

    [notify]
    title_info = { fg = "${c.info-blue}" }
    title_warn = { fg = "${c.caution-yellow}" }
    title_error = { fg = "${c.warning-red}" }

    [filetype]
    rules = [
      # Directories
      { name = "*/", fg = "${c.accent-amber}", bold = true },

      # Executables
      { mime = "application/x-executable", fg = "${c.accent-green}" },
      { mime = "application/x-sharedlib", fg = "${c.accent-green-dim}" },

      # Archives
      { mime = "application/zip", fg = "${c.caution-yellow}" },
      { mime = "application/gzip", fg = "${c.caution-yellow}" },
      { mime = "application/x-tar", fg = "${c.caution-yellow}" },
      { mime = "application/x-bzip2", fg = "${c.caution-yellow}" },
      { mime = "application/x-xz", fg = "${c.caution-yellow}" },
      { mime = "application/x-7z-compressed", fg = "${c.caution-yellow}" },
      { mime = "application/x-rar", fg = "${c.caution-yellow}" },

      # Documents
      { mime = "application/pdf", fg = "${c.warning-red}" },
      { mime = "application/doc", fg = "${c.info-blue}" },
      { mime = "application/msword", fg = "${c.info-blue}" },

      # Images
      { mime = "image/*", fg = "${c.accent-amber-glow}" },

      # Videos
      { mime = "video/*", fg = "${c.accent-amber}" },

      # Audio
      { mime = "audio/*", fg = "${c.accent-green}" },

      # Text/Code
      { mime = "text/*", fg = "${c.text-primary}" },
      { name = "*.nix", fg = "${c.info-blue}" },
      { name = "*.rs", fg = "${c.accent-amber}" },
      { name = "*.py", fg = "${c.caution-yellow}" },
      { name = "*.js", fg = "${c.caution-yellow}" },
      { name = "*.ts", fg = "${c.info-blue}" },
      { name = "*.lua", fg = "${c.info-blue}" },
      { name = "*.sh", fg = "${c.accent-green}" },
      { name = "*.md", fg = "${c.text-secondary}" },
      { name = "*.json", fg = "${c.caution-yellow}" },
      { name = "*.toml", fg = "${c.accent-amber}" },
      { name = "*.yaml", fg = "${c.accent-amber}" },
      { name = "*.yml", fg = "${c.accent-amber}" },

      # Config files
      { name = "*.conf", fg = "${c.accent-green-dim}" },
      { name = "*.cfg", fg = "${c.accent-green-dim}" },
      { name = "*.ini", fg = "${c.accent-green-dim}" },

      # Git
      { name = ".git*/", fg = "${c.warning-red}" },
      { name = ".gitignore", fg = "${c.text-tertiary}" },

      # Fallback
      { name = "*", fg = "${c.text-primary}" },
    ]
  '';

in {
  config = mkIf centurySeriesThemeCondition {
    # Install yazi theme
    xdg.configFile."yazi/theme.toml".text = yaziTheme;

    # Ensure yazi is enabled
    programs.yazi = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}
