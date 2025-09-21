# ~/nixos-config/modules/home-manager/programs/default.nix
# This file imports modules for home-manager program functionality. Themeing "ricing" is separate.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./kitty.nix
    ./firefox.nix
  ];
}