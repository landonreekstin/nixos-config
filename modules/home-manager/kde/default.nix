# ~/nixos-config/modules/home-manager/kde/default.nix
# This file acts as an aggregator for KDE Plasma functionality. Themeing "ricing" is separate.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./default-functional.nix
  ];
}