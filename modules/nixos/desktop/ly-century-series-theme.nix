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

      # UI colors — radar display palette
      bg                 = "0x000a0e14"; # deep instrument panel black — bg-primary
      fg                 = "0x0000ff41"; # radar phosphor green — accent-green
      border_fg          = "0x00004d18"; # dark radar green frame — border-primary
      error_fg           = "0x00ff3838"; # master warning red — warning-red

      # UI box sizing — larger than defaults (input_len=34, margin_box_h=2, margin_box_v=1)
      input_len          = 50;
      margin_box_h       = 6;
      margin_box_v       = 3;

      clock              = "%H:%M";
      hide_version_string = true;
      text_in_center     = true;
    };
  };
}
