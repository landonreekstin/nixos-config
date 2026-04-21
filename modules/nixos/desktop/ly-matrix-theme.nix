# ~/nixos-config/modules/nixos/desktop/ly-matrix-theme.nix
# Ly display manager "matrix" theme — classic digital rain aesthetic
{ config, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  enabled = dmCfg.enable && dmCfg.type == "ly" && dmCfg.ly.theme == "matrix";
in
{
  config = lib.mkIf enabled {
    services.displayManager.ly.settings = {
      animation  = "matrix";

      bg         = "0x00000000"; # black
      fg         = "0x0000ff41"; # phosphor green — text/input
      border_fg  = "0x00004d18"; # dark green border
      error_fg   = "0x00ff3838"; # master warning red

      clock               = "%H:%M";
      hide_version_string = true;
      text_in_center      = true;
    };
  };
}
