# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/default.nix
#
# The glade Hyprland desktop: insideabush's Glade, his
# pixel-art forest (pkgs/glade), as the whole Hyprland desktop. Always night.
#
# - desktop.nix  — structure: the glade on every monitor, floating windows with title
#                  bars, the plain-English bar, the Apps and power menus, keyboard steering
# - the rest     — the look, all from colors.nix: Hyprland's borders and title bars, the
#                  bar, rofi, wlogout, the lock screen, kitty, and GTK/icons/cursor
# - dock.nix     — the dock on the lower monitor, the title bars' minimise button, and
#                  new windows taking the keyboard as they open (dock.py)
{ ... }:
{
  imports = [
    ./desktop.nix
    ./dock.nix
    ./hyprland.nix
    ./waybar.nix
    ./rofi.nix
    ./wlogout.nix
    ./swaylock.nix
    ./kitty.nix
    ./gtk.nix
  ];
}
