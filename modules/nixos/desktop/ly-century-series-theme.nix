# ~/nixos-config/modules/nixos/desktop/ly-century-series-theme.nix
# Ly display manager "century-series" theme — Cold War aviation cockpit aesthetic
# Matches the Hyprland century-series theme: phosphor green matrix rain, amber CRT UI
{ config, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  enabled = dmCfg.enable && dmCfg.type == "ly" && dmCfg.ly.theme == "century-series";
in
{
  config = lib.mkIf enabled {
    services.displayManager.ly.settings = {
      animation          = "matrix";
      cmatrix_fg         = "0x007fda89"; # phosphor green — accent-green
      cmatrix_head_col   = "0x0039ff14"; # intense radar green — accent-radar

      bg                 = "0x000a0e14"; # deep instrument panel black — bg-primary
      fg                 = "0x00ff9e3b"; # amber CRT display — accent-amber
      border_fg          = "0x002a3441"; # gunmetal MFD frame — border-primary
      error_fg           = "0x00ff3838"; # master warning red — warning-red

      clock              = "%H:%M";
      hide_version_string = true;
      text_in_center     = true;
    };
  };
}
