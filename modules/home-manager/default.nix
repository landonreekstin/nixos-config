# ~/nixos-config/modules/home-manager/default.nix
# This file serves as the top level import point for all home-manager module default.nix import files.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    #./common-options.nix
    ./common/default.nix
    ./system/default.nix
  ];
}
