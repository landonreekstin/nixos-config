# ~/nixos-config/modules/nixos/desktop/ly-doom-theme.nix
# Ly display manager "doom" theme — doom fire animation with dark color scheme
{ config, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  enabled = dmCfg.enable && dmCfg.type == "ly" && dmCfg.ly.theme == "doom";
in
{
  config = lib.mkIf enabled {
    services.displayManager.ly.settings = {
      animation       = "doom";
      doom_top_color  = "0x00FF4500"; # orange-red at the tip
      doom_middle_color = "0x00FF8C00"; # dark orange in the middle
      doom_bottom_color = "0x00CC0000"; # deep red at the base

      bg              = "0x00000000"; # black background
      fg              = "0x00FF8C00"; # orange foreground text
      border_fg       = "0x00FF4500"; # orange-red border

      clock           = "%H:%M";
      hide_version_string = true;
      text_in_center  = true;
    };
  };
}
