# ~/nixos-config/modules/home-manager/xfce/default.nix
# Aggregator for base XFCE functionality. Theming ("ricing") is separate, under
# modules/home-manager/themes/windows7-xfce/.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./functional.nix
    ./monitors.nix
  ];
}
