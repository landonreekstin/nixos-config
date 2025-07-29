# ~/nixos-config/modules/nixos/homelab/default.nix
# This file serves as the import point for homelab modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./samba.nix
    ./jellyfin.nix
  ];
}