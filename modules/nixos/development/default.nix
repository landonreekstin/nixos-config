# ~/nixos-config/modules/nixos/development/default.nix
# This file serves as the import point for nixos development modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./fpga-ice40.nix
    ./kernel.nix
    ./embedded-linux.nix
    ./gbdk.nix
  ];
}
