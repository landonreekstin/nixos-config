# ~/nixos-config/modules/home-manager/common/default.nix
# This file serves as the import point for home-manager common modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./git.nix
    ./home-base.nix
  ];
}
