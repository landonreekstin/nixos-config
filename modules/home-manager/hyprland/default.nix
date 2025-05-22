# ~/nixos-config/modules/home-manager/hyprland/default.nix
# This file acts as an aggregator for Hyprland functionality. Themeing "ricing" is separate.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./functional.nix
  ];
}