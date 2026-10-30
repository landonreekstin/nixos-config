# ~/nixos-config/modules/nixos/programs/default.nix
# This file serves as the import point for profile modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./options.nix
    ./flatpak.nix
    ./partydeck.nix
    ./iw4x.nix
    ./batman.nix
    ./steel-horizon.nix
    ./sub-of-seas.nix
    ./r62d.nix
    ./vibenote.nix
    ./quiver.nix
    ./claude-code.nix
    ./vibe-projects.nix
  ];
}