# ~/nixos-config/modules/home-manager/hyprland/default.nix
# Hyprland: the functional layer every desktop shares, and the desktops built on it
# (desktops.nix imports desktops/<name>/). Themes still in ../themes/ are separate.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./functional.nix
    ./desktops.nix
    ./desktop-apps.nix
  ];
}
