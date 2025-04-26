# Placeholder for Century Series Hyprland Rice
{ config, pkgs, lib, ... }:

{
  imports = [
    # ./konsole.nix # Still commented
    # ./colors.nix
    ./hyprland.nix # <-- ADD THIS IMPORT
    # ./style.nix
    # ./icons.nix
    # ./fonts.nix
    ./waybar.nix
    # ./wofi.nix   # Placeholder for later
    # ./swaylock.nix # Placeholder for later
    # ./swaync.nix # Placeholder for later
    # ./wallpaper.nix # Placeholder for later
  ];

}
