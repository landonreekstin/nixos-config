# ~/nixos-config/modules/nixos/common/default.nix
# This file serves as the import point for common modules to be used in all hosts.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./bootloader.nix
    ./nix-settings.nix
    ./internationalisation.nix
    ./users-groups.nix
    ./system-tweaks.nix
    ./base-environment.nix
  ];
}