# ~/nixos-config/modules/home-manager/themes/default.nix
# Plasma and XFCE themes. Hyprland desktops live in ../hyprland/desktops/.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./aerothemeplasma/plasma-user.nix
    ./windows7-xfce/default.nix
    ./plasma-default.nix
    ./plasma-bigsur.nix
  ];
}
