# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/wlogout.nix
#
# The power menu: the night sky over the screen and five big wooden boards, each saying
# what it does, each glowing in its own colour. The actions are in desktop.nix.
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.hyprland.desktops.default == "glade";
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
      window { background-color: alpha(${c.night}, 0.86); }
      button {
        margin: 40px 14px;
        min-width: 180px;
        min-height: 150px;
        font-size: 26px;
        color: ${c.text};
        background-color: ${c.board};
        border: 3px solid ${c.ink};
        border-radius: 14px;
        box-shadow: 0 4px 0 ${c.ink};
      }
      button:hover, button:focus { background-color: ${c.boardHi}; color: #ffffff; outline: none; }
      #lock     { border-color: ${c.cyan}; }
      #logout   { border-color: ${c.violet}; }
      #suspend  { border-color: ${c.moss}; }
      #reboot   { border-color: ${c.amber}; }
      #shutdown { border-color: ${c.pink}; }
      #cancel   { border-color: ${c.text}; }
    '';
  };
}
