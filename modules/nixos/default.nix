# ~/nixos-config/modules/nixos/default.nix
# This file serves as the top level import point for all nixos module default.nix import files.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./common-options.nix
    ./unstable-overlay.nix
    ./common/default.nix
    ./services/default.nix
    ./profiles/default.nix
    ./programs/default.nix
    ./hardware/default.nix
    ./desktop/default.nix
    ./development/default.nix
    ./homelab/default.nix
  ];
}