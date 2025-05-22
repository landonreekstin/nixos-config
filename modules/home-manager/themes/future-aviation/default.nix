# ~/nixos-config/modules/home-manager/themes/future-aviation/default.nix
{ ... }: # Add config, pkgs, lib if specific options here need them. Usually not for a simple import aggregator.

{
  imports = [
    ./hyprland-rice.nix
    # We will add ./waybar.nix here later
  ];
}