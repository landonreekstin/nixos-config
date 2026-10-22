# ~/nixos-config/modules/home-manager/themes/glade/waybar.nix
{ config, pkgs, lib, customConfig, ... }:

let
  on = customConfig.desktop.hyprland.glade.enable
    && lib.elem "hyprland" customConfig.desktop.environments;
  c = import ./colors.nix;
in
{
  config = lib.mkIf on {
    programs.waybar.settings.mainBar = {
      height = lib.mkForce 40;
      spacing = lib.mkForce 0;
      clock = {
        format = "{:%a %d %b  %I:%M %p}";
      };
    };

    # Chunky, pixel-ish buttons: an ink outline with a hard 2px drop shadow, like the
    # wooden plaques in the glade.
    programs.waybar.style = ''
      * {
        font-family: "${c.font}", "Noto Color Emoji", sans-serif;
        font-size: 15px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: alpha(${c.cream}, 0.94);
        color: ${c.ink};
        border-bottom: 3px solid ${c.pink};
      }

      tooltip {
        background: ${c.ink};
        border: 2px solid ${c.pink};
        border-radius: 8px;
      }
      tooltip label { color: ${c.cream}; }

      #custom-glade-home, #custom-glade-apps, #custom-power,
      #taskbar button, #pulseaudio, #clock, #tray {
        margin: 5px 4px 6px 4px;
        padding: 0 12px;
        color: ${c.ink};
        background: ${c.light};
        border: 2px solid ${c.ink};
        border-radius: 8px;
        box-shadow: 0 2px 0 ${c.ink};
      }

      #custom-glade-home { background: ${c.leaf2}; margin-left: 10px; }
      #custom-glade-apps { background: ${c.lav}; }
      #custom-power      { background: ${c.pink}; margin-right: 10px; }

      #custom-glade-home:hover, #custom-glade-apps:hover, #custom-power:hover,
      #taskbar button:hover, #pulseaudio:hover, #clock:hover {
        background: ${c.cream};
      }

      #taskbar button.active { background: ${c.pink2}; }
      #taskbar button.minimized { opacity: 0.6; }

      #clock, #pulseaudio, #tray { background: ${c.earth}; }
    '';
  };
}
