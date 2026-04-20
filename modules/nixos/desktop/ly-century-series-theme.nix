# ~/nixos-config/modules/nixos/desktop/ly-century-series-theme.nix
# Ly display manager "century-series" theme — Cold War aviation cockpit aesthetic
# Uses a custom F-18 ASCII animation (.dur file) as the login screen background.
{ config, lib, ... }:

let
  dmCfg = config.customConfig.desktop.displayManager;
  enabled = dmCfg.enable && dmCfg.type == "ly" && dmCfg.ly.theme == "century-series";
in
{
  config = lib.mkIf enabled {

    # Deploy the pre-generated .dur animation file to /etc/ly/
    environment.etc."ly/f18-animation.dur" = {
      source = ../../../assets/ly/f18-animation.dur;
      mode   = "0444";
    };

    services.displayManager.ly.settings = {
      # Custom F-18 ASCII animation
      animation          = "dur_file";
      dur_file_path      = "/etc/ly/f18-animation.dur";
      dur_offset_alignment = "center";
      dur_x_offset       = 0;
      dur_y_offset       = 0;

      # UI colors — Cold War cockpit palette
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
