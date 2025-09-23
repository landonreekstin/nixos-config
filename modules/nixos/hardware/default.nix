# ~/nixos-config/modules/nixos/hardware/default.nix
# This file serves as the import point for hardware modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./nvidia.nix
    ./peripherals.nix
  ];
}