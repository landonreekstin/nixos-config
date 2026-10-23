# ~/nixos-config/modules/home-manager/themes/glade/hyprland.nix
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "glade";
  c = import ./colors.nix;
  rgb = x: "rgb(${lib.removePrefix "#" x})";
in
{
  config = lib.mkIf on {

    wayland.windowManager.hyprland.settings = {
      general = {
        gaps_in = 6;
        gaps_out = 12;
        border_size = 3;
        "col.active_border" = "${rgb c.pink} ${rgb c.violet} 45deg";
        "col.inactive_border" = rgb c.board;
      };

      decoration = {
        rounding = 10;
        dim_inactive = false;
        shadow = {
          enabled = true;
          range = 18;
          render_power = 3;
          color = "rgba(0a061899)";
        };
        blur.enabled = false;
      };

      # Soft and a little bouncy — things pop in like the glade's petals, nothing slides.
      animations = {
        enabled = true;
        bezier = [ "soft, 0.22, 1.0, 0.36, 1.0" "pop, 0.34, 1.4, 0.64, 1.0" ];
        animation = [
          "windows, 1, 4, pop, popin 85%"
          "windowsOut, 1, 3, soft, popin 85%"
          "fade, 1, 4, soft"
          "border, 1, 6, soft"
          "workspaces, 1, 4, soft, fade"
          "layers, 1, 4, soft, fade"
        ];
      };

      # Title bars: a carved wooden board, the window's name in the glade's pixel font.
      plugin.hyprbars = {
        bar_height = 32;
        bar_color = rgb c.board;
        "col.text" = rgb c.text;
        bar_text_font = c.font;
        bar_text_size = 14;
        bar_text_align = "left";
        bar_padding = 12;
        bar_button_padding = 8;
        bar_part_of_window = true;
        bar_precedence_over_border = true;
        inactive_button_color = rgb c.boardHi;
      };
    };

    # Apps follow the glade's night: dark GTK and Qt (gtk.nix sets the GTK theme itself).
    wayland.windowManager.hyprland.extraConfig = ''
      env = GTK_THEME,Adwaita:dark
      env = QT_STYLE_OVERRIDE,adwaita-dark
    '';
  };
}
