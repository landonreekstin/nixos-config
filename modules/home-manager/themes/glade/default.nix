# ~/nixos-config/modules/home-manager/themes/glade/default.nix
#
# The glade Hyprland theme (themes.hyprland = "glade"): insideabush's Glade, his
# pixel-art forest (pkgs/glade), as the whole Hyprland desktop. Always night.
#
# - desktop.nix  — structure: the glade on every monitor, floating windows with title
#                  bars, the plain-English bar, the Apps and power menus, keyboard steering
# - the rest     — the look, all from colors.nix: Hyprland's borders and title bars, the
#                  bar, rofi, wlogout, the lock screen, kitty, and GTK/icons/cursor
{ ... }:
{
  imports = [
    ./desktop.nix
    ./hyprland.nix
    ./waybar.nix
    ./rofi.nix
    ./wlogout.nix
    ./swaylock.nix
    ./kitty.nix
    ./gtk.nix
  ];
}
