# ../../modules/home-manager/programs/kitty.nix
{ config, lib, ... }:
{
  programs.kitty = {
    enable = true;
    # Basic, non-theme settings
    settings = {
      cursor_shape = "block";
      cursor_blink_interval = 0.5;
      scrollback_lines = 2000;
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
    };
    # Font, color, and other appearance settings should be
    # contributed by your theme modules (e.g., future-aviation)
    # by also targeting programs.kitty.settings.
  };
}