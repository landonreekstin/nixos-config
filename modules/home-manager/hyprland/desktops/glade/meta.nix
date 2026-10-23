# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/meta.nix
# What the NixOS side needs to know about this desktop (modules/nixos/desktop/
# hyprland.nix reads every desktops/<name>/meta.nix): a plain attrset, not a module.
{
  # The display-manager entry's name, when this is not the default desktop.
  label = "Glade";
}
