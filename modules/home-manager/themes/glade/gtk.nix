# ~/nixos-config/modules/home-manager/themes/glade/gtk.nix
#
# Dark GTK, Papirus icons (the Apps menu shows them) and the fonts the theme uses.
# These options are session-global: the XFCE session on the same host reads them too
# (themes/windows7-xfce selects its own by name inside XFCE).
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "glade";
in
{
  config = lib.mkIf on {
    home.packages = [ pkgs.departure-mono pkgs.nerd-fonts.jetbrains-mono pkgs.papirus-icon-theme ];
    fonts.fontconfig.enable = true;

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    # Over the glade itself the pointer is the glade's own pixel cursor (wayland.py).
    home.pointerCursor = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
    };
  };
}
