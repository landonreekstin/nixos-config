# ~/nixos-config/modules/home-manager/de-wm-components/waybar/default.nix
{ ... }: # Add config, pkgs, lib if functional.nix options need them at the top level of default.nix
{
  imports = [
    ./functional.nix
  ];
}