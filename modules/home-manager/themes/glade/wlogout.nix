# ~/nixos-config/modules/home-manager/themes/glade/wlogout.nix
#
# The power menu: a soft mist over the screen and five big plaque-like buttons, each
# saying what it does. The actions are in hyprland/glade.nix.
{ config, pkgs, lib, customConfig, ... }:

let
  on = customConfig.desktop.hyprland.glade.enable
    && lib.elem "hyprland" customConfig.desktop.environments;
  c = import ./colors.nix;
in
{
  config = lib.mkIf on {
    programs.wlogout.style = ''
      * {
        font-family: "${c.font}", sans-serif;
        background-image: none;
        box-shadow: none;
      }
      window { background-color: alpha(${c.mist}, 0.82); }
      button {
        margin: 40px 14px;
        min-width: 180px;
        min-height: 150px;
        font-size: 26px;
        color: ${c.ink};
        background-color: ${c.cream};
        border: 3px solid ${c.ink};
        border-radius: 14px;
        box-shadow: 0 4px 0 ${c.ink};
      }
      button:hover, button:focus { background-color: ${c.pink2}; outline: none; }
      #lock     { background-color: ${c.sky}; }
      #logout   { background-color: ${c.lav}; }
      #suspend  { background-color: ${c.leaf2}; }
      #reboot   { background-color: ${c.earth}; }
      #shutdown { background-color: ${c.pink}; }
      #cancel   { background-color: ${c.cream}; }
      #lock:hover, #logout:hover, #suspend:hover, #reboot:hover, #shutdown:hover {
        background-color: ${c.cream};
      }
    '';
  };
}
