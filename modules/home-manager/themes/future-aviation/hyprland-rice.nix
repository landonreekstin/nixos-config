# ~/nixos-config/modules/home-manager/hyprland/future-aviation-rice.nix
{ config, pkgs, lib, customConfig, ... }:

let
  # Wallpaper paths are theme-specific
  wallpaperDir = config.home.homeDirectory + "/.local/share/wallpapers";
  wallpaperF104 = wallpaperDir + "/f104-retro-future.jpg";
  wallpaperHangar3 = wallpaperDir + "/future-aviation-hanger-3.jpg";
  wallpaperHangar1 = wallpaperDir + "/future-aviation-hanger-1.jpg";
  wallpaperSu47 = wallpaperDir + "/su-47-future.jpg";

  # Monitor descriptions for hyprpaper (can be different from functional layout if needed)
  # Using the same ones for consistency for now
  monitorDescMainDell = "Dell Inc. DELL S2721HGF DZR2123";
  monitorDescLeftVirt = "Dell Inc. OptiPlex 7760 0x36419E0A";
  monitorDescRightVirt = "Samsung Electric Company S27R65x H4TW800293";
  monitorDescTV = "Hisense Electric Co. Ltd. 4Series43 0x00000278";

  # Check if home-manager, Hyprland, and the Future Aviation theme are enabled
  futureAviationThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "future-aviation";
in
{
  config = lib.mkIf futureAviationThemeCondition {
    # -------------------------------------------------------------------------- #
    # Wallpaper File Linking (Theme Specific)
    # -------------------------------------------------------------------------- #
    home.file.".local/share/wallpapers/future-aviation-hanger-3.jpg".source = ../../../../assets/wallpapers/future-aviation-hanger-3.jpg;
    home.file.".local/share/wallpapers/f104-retro-future.jpg".source = ../../../../assets/wallpapers/f104-retro-future.jpg;
    home.file.".local/share/wallpapers/su-47-future.jpg".source = ../../../../assets/wallpapers/su-47-future.jpg;
    home.file.".local/share/wallpapers/future-aviation-hanger-1.jpg".source = ../../../../assets/wallpapers/future-aviation-hanger-1.jpg;

    # -------------------------------------------------------------------------- #
    # Hyprpaper Service (Theme Specific - for setting wallpapers)
    # -------------------------------------------------------------------------- #
    services.hyprpaper = {
      enable = true;
      settings = {
        preload = [ wallpaperF104 wallpaperHangar3 wallpaperHangar1 wallpaperSu47 ];
        wallpaper = [
          "desc:${monitorDescMainDell},${wallpaperHangar3}"
          "desc:${monitorDescLeftVirt},${wallpaperF104}"
          "desc:${monitorDescRightVirt},${wallpaperSu47}"
          "desc:${monitorDescTV},${wallpaperHangar1}"
        ];
        ipc = false;
        splash = false;
      };
    };

    # -------------------------------------------------------------------------- #
    # Hyprland Theming Configuration
    # -------------------------------------------------------------------------- #
    wayland.windowManager.hyprland = {
      # No need for enable = true; or package = null; here,
      # as those are set in functional.nix and these settings will be merged.

      settings = {
        # General theming settings
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.inactive_border" = "rgba(808080aa)";
          "col.active_border" = "rgba(DAA520ff)";
          # layout = "dwindle"; # This is functional, so it stays in functional.nix
        };

        # Decoration settings
        decoration = {
          rounding = 3;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
          # drop_shadow = true; # Example if you want to enable
          # shadow_range = 4;
          # shadow_render_power = 3;
          # "col.shadow" = "rgba(1a1a1a99)";
        };

        # Animations settings
        animations = {
          enabled = true;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        # Potentially theme-related misc settings (though most were functional)
        # misc = {
        #   # Example: if some 'misc' settings are purely visual
        # };

        # Window rules that are purely for aesthetics (e.g., opacity for certain windows)
        # windowrulev2 = [
        #   "opacity 0.9 override 0.9 override,class:^(kitty)$" # Example
        # ];
      }; # End of settings

      # Use `extraConfig` for any raw Hyprland config lines for theming,
      # like sourcing external theme files.
      # extraConfig = ''
      #   # Example: source = ~/.config/hypr/themes/future-aviation.conf
      # '';
    }; # End of wayland.windowManager.hyprland
  };
}