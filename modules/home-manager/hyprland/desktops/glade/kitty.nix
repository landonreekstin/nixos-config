# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/kitty.nix
#
# The terminal, where he spends his time in Claude sessions: the glade's glows on its
# night sky. The font must be the Nerd Font build of JetBrains Mono — only it carries the
# icon glyphs Claude Code and the prompt print (see ../century-series/kitty.nix).
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.hyprland.desktops.default == "glade";
  c = import ./colors.nix;
in
{
  config = lib.mkIf on {
    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };
      settings = {
        window_padding_width = 8;
        # The Glade's Claude panel types his replies into the terminal Claude runs in
        # (pkgs/glade: claude_panel.py), through this socket, which only he can open.
        allow_remote_control = "socket-only";
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-{kitty_pid}";
        background = c.night;
        foreground = c.text;
        cursor = c.moss;
        cursor_text_color = c.ink;
        selection_background = c.boardHi;
        selection_foreground = c.text;
        url_color = c.cyan;
        active_tab_background = c.boardHi;
        active_tab_foreground = c.text;
        inactive_tab_background = c.board;
        inactive_tab_foreground = c.text;
      } // lib.listToAttrs (lib.imap0 (i: v: lib.nameValuePair "color${toString i}" v) c.terminal);
    };
  };
}
