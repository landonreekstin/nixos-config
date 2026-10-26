# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/rofi.nix
#
# The "Apps" menu: a night-sky card in the middle of the screen, big icons, two columns,
# the hovered app on a lit wooden board; a click beside it closes it. Click behaviour
# is in desktop.nix.
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.hyprland.desktops.default == "glade";
  c = import ./colors.nix;
  l = config.lib.formats.rasi.mkLiteral;
in
{
  config = lib.mkIf on {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;
      font = "${c.font} 14";
      extraConfig = {
        modi = "drun";
        show-icons = true;
        icon-theme = "Papirus";
        drun-display-format = "{name}";
        display-drun = "Open an app";
      };
      theme = {
        "*" = {
          background-color = l "transparent";
          text-color = l c.text;
        };
        # The menu covers its whole screen, so a click beside the card lands on rofi and
        # closes it (kb-cancel in desktop.nix; Wayland rofi has no click-to-exit). The card
        # itself is the mainbox, centred by its margins.
        window = {
          fullscreen = true;
          background-color = l "rgba(10, 6, 24, 0.2)";
        };
        mainbox = {
          margin = l "calc(50% - 265px) calc(50% - 380px)";
          background-color = l c.night;
          border = l "3px solid";
          border-color = l c.violet;
          border-radius = l "14px";
          padding = l "18px";
          spacing = l "14px";
        };
        inputbar = {
          background-color = l c.board;
          border = l "2px solid";
          border-color = l c.ink;
          border-radius = l "10px";
          padding = l "10px 14px";
          spacing = l "10px";
          children = map l [ "prompt" "entry" ];
        };
        prompt.text-color = l c.moss;
        entry.placeholder = "type to search, or just click";
        listview = {
          columns = 2;
          lines = 8;
          spacing = l "6px";
          fixed-height = true;
        };
        element = {
          padding = l "8px 12px";
          spacing = l "12px";
          border-radius = l "10px";
        };
        "element selected" = {
          background-color = l c.boardHi;
          border = l "2px solid";
          border-color = l c.pink;
        };
        element-icon.size = l "32px";
        element-text.vertical-align = l "0.5";
      };
    };
  };
}
