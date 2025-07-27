# ~/nixos-config/modules/nixos/profiles/default.nix
# This file serves as the import point for profile modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./gaming.nix
    ./partydeck.nix
  ];
}