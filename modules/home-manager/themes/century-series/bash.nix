# ~/nixos-config/modules/home-manager/themes/century-series/bash.nix
{ config, pkgs, lib, customConfig, ... }:

let
  centurySeriesThemeCondition = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "century-series";
in

lib.mkIf centurySeriesThemeCondition {

  home.packages = [ pkgs.starship ];

  # Century Series starship config lives in app-themes.nix and is written to
  # ~/.config/starship.toml by night-mode.nix, which owns that path so it can
  # swap day/night. Not a home.file here: the two would fight over it.

  # Activate starship only inside kitty — TTY, SSH, and other terminals
  # continue using the standard bash prompt from bash.nix
  programs.bash.bashrcExtra = lib.mkAfter ''
    if [ -n "$KITTY_WINDOW_ID" ]; then
      eval "$(starship init bash)"
    fi
  '';
}
