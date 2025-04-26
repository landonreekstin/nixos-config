# Placeholder for Century Series Hyprland Rice
{ config, pkgs, lib, ... }:

{
  imports = [
    # ./konsole.nix # Still commented
    ./colors.nix
    ./hyprland.nix # <-- ADD THIS IMPORT
    # ./style.nix
    # ./icons.nix
    # ./fonts.nix
    # ./waybar.nix # Placeholder for later
    # ./wofi.nix   # Placeholder for later
    # ./swaylock.nix # Placeholder for later
    # ./swaync.nix # Placeholder for later
    # ./wallpaper.nix # Placeholder for later
  ];

  config = {
    programs.plasma.enable = true; # Keep this for KDE color scheme integration if desired, or remove if purely Hyprland
  };
}
