# ~/nixos-config/modules/home-manager/themes/glade/default.nix
#
# The look of the Glade desktop (customConfig.desktop.hyprland.glade): everything
# Hyprland itself draws — window borders and title bars, the bar, the app menu, the
# power menu. Active whenever the glade desktop is on, whatever themes.hyprland says;
# that theme keeps styling the apps themselves. What runs and what each click does is
# in modules/home-manager/hyprland/glade.nix.
{ ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./rofi.nix
    ./wlogout.nix
  ];
}
