# ~/nixos-config/modules/home-manager/default.nix
# This file serves as the top level import point for all home-manager module default.nix import files.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./common/default.nix  # Sets home options and home-manager.enable from above options, must be imported second
    ./de-wm-components/default.nix
    ./hyprland/default.nix
    ./programs/default.nix
    ./services/default.nix
    ./system/default.nix
    ./themes/default.nix
  ];
}

# Note: ./scripts is not imported here, as it is not a module but a collection of scripts.
# A module that requires scripts should import them directly.
# Themes are also not imported here, the current structure uses a direct import of the
# ./theme/<theme-name>/default.nix in the hosts/<host-name>/home.nix to set the desired theme.
# Future refactoring will give themes a hmcustomConfig option to enable in home.nix.