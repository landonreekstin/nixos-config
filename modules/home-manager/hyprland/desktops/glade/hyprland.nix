# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/hyprland.nix
{ config, pkgs, lib, customConfig, ... }:

let
  inherit ((import ../lib.nix { inherit lib; }).state customConfig "glade") enabled;
  c = import ./colors.nix;
  rgb = x: "rgb(${lib.removePrefix "#" x})";

  # A kdeglobals holding only the Breeze Dark palette, in a directory of its own that is
  # put in front of XDG_CONFIG_DIRS for this desktop alone (below). KDE apps cascade
  # kdeglobals through XDG_CONFIG_DIRS, so under the glade they read this palette, while
  # the same apps in any other session (XFCE) never see it. ~/.config/kdeglobals still
  # wins key by key, so it must not carry [Colors:*] groups of its own.
  kdeDarkColors = pkgs.runCommand "glade-kde-colors" { } ''
    install -Dm644 ${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors $out/kdeglobals
  '';
in
{
  config = lib.mkIf enabled {

    # Its bar, menus, lock screen, terminal and GTK theme come along when it is a
    # second session (../../desktop-apps.nix).
    hyprDesktops.glade.ownApps = true;

    hyprDesktops.glade.settings = {
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
    # The Qt platform theme ("kde") is set in hyprland/functional.nix; this picks the
    # widget style (Breeze, not "adwaita-dark", which no host packages) and the palette
    # (kdeDarkColors above). hyprlang expands $XDG_CONFIG_DIRS from the environment, so
    # the session's own entries (menus, autostart) are kept behind it. The dbus/systemd
    # push is for apps started on demand rather than by Hyprland — e.g. a Dolphin opened
    # by a browser's "show in folder" — which would otherwise come up light.
    hyprDesktops.glade.extraConfig = ''
      env = GTK_THEME,Adwaita:dark
      env = QT_STYLE_OVERRIDE,Breeze
      env = XDG_CONFIG_DIRS,${kdeDarkColors}:$XDG_CONFIG_DIRS
      exec-once = dbus-update-activation-environment --systemd XDG_CONFIG_DIRS
    '';
  };
}
