# ~/nixos-config/modules/home-manager/themes/glade/swaylock.nix
#
# The lock screen ("Lock" in the power menu, Super+Esc): the night sky, and a ring that
# glows like the moss while he types.
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.themes.hyprland == "glade";
  c = import ./colors.nix;
  hex = lib.removePrefix "#";
in
{
  config = lib.mkIf on {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        color = hex c.night;
        font = c.font;
        font-size = 22;
        clock = true;
        indicator = true;
        indicator-radius = 110;
        indicator-thickness = 12;
        inside-color = hex c.board;
        inside-clear-color = hex c.board;
        inside-ver-color = hex c.boardHi;
        inside-wrong-color = hex c.board;
        ring-color = hex c.violet;
        ring-clear-color = hex c.cyan;
        ring-ver-color = hex c.moss;
        ring-wrong-color = hex c.pink;
        key-hl-color = hex c.moss;
        bs-hl-color = hex c.pink;
        line-color = hex c.ink;
        separator-color = hex c.ink;
        text-color = hex c.text;
        text-clear-color = hex c.text;
        text-ver-color = hex c.text;
        text-wrong-color = hex c.pink;
      };
    };
  };
}
