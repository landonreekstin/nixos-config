# ~/nixos-config/modules/home-manager/themes/plasma-windows7/default.nix
{ ... }: # Add config, pkgs, lib if specific options here need them. Usually not for a simple import aggregator.

{
  imports = [
    ./plasma-rice.nix
  ];
}