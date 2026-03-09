# ~/nixos-config/modules/home-manager/themes/century-series/btop.nix
# Century Series theme for btop - Cold War aviation cockpit aesthetic
{ config, pkgs, lib, customConfig, ... }:

with lib;

let
  # Import colors
  colorsModule = import ./colors.nix { };
  c = colorsModule.centuryColors;

  # Check if century-series theme is enabled
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";

  # btop theme file content
  btopTheme = ''
    # Century Series Theme for btop
    # Cold War Aviation Cockpit Aesthetic

    # Main background
    theme[main_bg]="${c.bg-primary}"

    # Main text color
    theme[main_fg]="${c.text-primary}"

    # Title color for boxes
    theme[title]="${c.accent-amber}"

    # Highlight color for keyboard shortcuts
    theme[hi_fg]="${c.accent-amber-glow}"

    # Background color of selected item in processes box
    theme[selected_bg]="${c.bg-secondary}"

    # Foreground color of selected item in processes box
    theme[selected_fg]="${c.accent-amber}"

    # Color of inactive/disabled text
    theme[inactive_fg]="${c.text-tertiary}"

    # Color of text appearing on top of graphs
    theme[graph_text]="${c.accent-green}"

    # Background color of the meter bar
    theme[meter_bg]="${c.border-primary}"

    # Misc colors for processes box including mini cpu graphs, subtle hierarchies, andடும்
    theme[proc_misc]="${c.accent-green-dim}"

    # CPU box outline color
    theme[cpu_box]="${c.border-primary}"

    # Memory/disks box outline color
    theme[mem_box]="${c.border-primary}"

    # Net up/down box outline color
    theme[net_box]="${c.border-primary}"

    # Processes box outline color
    theme[proc_box]="${c.border-primary}"

    # Box divider line and target box/boxes outline color on mouse hover
    theme[div_line]="${c.border-secondary}"

    # Temperature graph colors (green to red)
    theme[temp_start]="${c.accent-green}"
    theme[temp_mid]="${c.caution-yellow}"
    theme[temp_end]="${c.warning-red}"

    # CPU graph colors (green phosphor style)
    theme[cpu_start]="${c.accent-green-dim}"
    theme[cpu_mid]="${c.accent-green}"
    theme[cpu_end]="${c.accent-radar}"

    # Mem/Disk free meter (amber style)
    theme[free_start]="${c.accent-amber-dim}"
    theme[free_mid]="${c.accent-amber}"
    theme[free_end]="${c.accent-amber-glow}"

    # Mem/Disk cached meter
    theme[cached_start]="${c.info-blue}"
    theme[cached_mid]="${c.info-blue}"
    theme[cached_end]="${c.info-blue}"

    # Mem/Disk available meter
    theme[available_start]="${c.accent-green-dim}"
    theme[available_mid]="${c.accent-green}"
    theme[available_end]="${c.accent-green}"

    # Mem/Disk used meter (warning colors)
    theme[used_start]="${c.caution-yellow}"
    theme[used_mid]="${c.accent-amber}"
    theme[used_end]="${c.warning-red}"

    # Download graph colors
    theme[download_start]="${c.accent-green-dim}"
    theme[download_mid]="${c.accent-green}"
    theme[download_end]="${c.accent-radar}"

    # Upload graph colors
    theme[upload_start]="${c.accent-amber-dim}"
    theme[upload_mid]="${c.accent-amber}"
    theme[upload_end]="${c.accent-amber-glow}"

    # Process box color gradient for threads, memory, and cpu usage
    theme[process_start]="${c.accent-green-dim}"
    theme[process_mid]="${c.accent-amber}"
    theme[process_end]="${c.warning-red}"
  '';

in {
  config = mkIf centurySeriesThemeCondition {
    # Install btop theme
    xdg.configFile."btop/themes/century-series.theme".text = btopTheme;

    # Configure btop to use the theme
    # Note: btop package is installed separately (btop-rocm in functional.nix)
    programs.btop = {
      enable = true;
      package = pkgs.btop-rocm;
      settings = {
        color_theme = "century-series";
        theme_background = true;
        vim_keys = true;
      };
    };
  };
}
