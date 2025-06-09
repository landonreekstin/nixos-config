# ~/nixos-config/modules/home-manager/system/default.nix
# This file serves as the import point for home-manager system modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./gammastep.nix
    ./bash.nix
    ./xdg.nix
  ];
}
