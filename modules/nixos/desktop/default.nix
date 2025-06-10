# ~/nixos-config/modules/nixos/desktop/default.nix
# This file serves as the import point for desktop modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./display-manager.nix
    ./cosmic.nix
    ./hyprland.nix
    ./kde.nix
  ];
}