# ~/nixos-config/modules/nixos/homelab/default.nix
# This file serves as the import point for homelab modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./nas-client.nix
    ./samba.nix
    ./jellyfin.nix
    ./media-setup.nix
    ./transmission.nix
    ./arr.nix
    ./mullvad.nix
    ./jellyseerr.nix
    ./flaresolverr.nix
    ./media-linker.nix
    ./nix-cache.nix
  ];
}