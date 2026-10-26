# ~/nixos-config/modules/nixos/apps/default.nix
# This file serves as the import point for the customConfig.apps option namespace.
{ ... }:
{
  imports = [
    ./kde-suite.nix
    ./programs.nix
    ./xdg-defaults.nix
  ];
}
