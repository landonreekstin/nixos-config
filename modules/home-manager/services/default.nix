# ~/nixos-config/modules/home-manager/services/default.nix
# This file serves as the import point for home-manager service modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./gammastep.nix
    ./ssh.nix
  ];
}
