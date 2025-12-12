# ~/nixos-config/modules/home-manager/de-wm-components/default.nix
{ ... }: # Add config, pkgs, lib if functional.nix options need them at the top level of default.nix
{
  imports = [
    ./waybar/default.nix
    ./polkit/default.nix
  ];
}