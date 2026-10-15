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
      # Use xterm-256color so SSH sessions to remote hosts without kitty's
      # terminfo (e.g. OpenBSD) work correctly with programs like nano.
      term = "xterm-256color";

      # Defaults to yes, which breaks tiling. kitty persists the last OS-window
      # size AND STATE to ~/.cache/kitty/main.json and asks for it again at
      # startup. Under Hyprland the configure event for an ordinary tiled window
      # carries the maximized state, so kitty records
      #   {"window-size": [...], "window-state": "maximized"}
      # on essentially every exit — and every subsequent kitty then opens
      # maximized, covering the tiled layout instead of joining it. Deleting the
      # cache only helps until the next launch rewrites it.
      #
      # A remembered geometry is meaningless under a tiling compositor anyway:
      # the layout decides the size.
      remember_window_size = "no";
    };
    # Font, color, and other appearance settings should be
    # contributed by your theme modules (e.g., future-aviation)
    # by also targeting programs.kitty.settings.
  };
}