# ~/nixos-config/modules/home-manager/themes/default.nix
# This file serves as the import point for home-manager theme modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./aerothemeplasma/plasma-user.nix
    ./future-aviation/default.nix # We will include this in the future when the modules are conditionally enabled
    ./century-series/default.nix
    ./plasma-default.nix
  ];
}
