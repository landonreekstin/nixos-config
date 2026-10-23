# ~/nixos-config/modules/home-manager/hyprland/desktops/xbox360/meta.nix
# What the NixOS side needs to know about this desktop (modules/nixos/desktop/
# hyprland.nix reads every desktops/<name>/meta.nix): a plain attrset, not a module.
{
  # The display-manager entry's name.
  label = "Xbox 360 Dashboard";
  # The controller daemon emulates a mouse and keyboard through /dev/uinput.
  needsUinput = true;
}
