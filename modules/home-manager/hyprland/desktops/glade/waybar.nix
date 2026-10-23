# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/waybar.nix
{ config, pkgs, lib, customConfig, ... }:

let
  on = lib.elem "hyprland" customConfig.desktop.environments
    && customConfig.homeManager.hyprland.desktops.default == "glade";
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

    # The night sky with a line of glowing moss along it, and chunky wooden-board
    # buttons (an ink outline, a hard 2px drop shadow) like the name boards in the glade.
    programs.waybar.style = ''
      * {
        font-family: "${c.font}", "Noto Color Emoji", sans-serif;
        font-size: 15px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: alpha(${c.night}, 0.92);
        color: ${c.text};
        border-bottom: 2px solid alpha(${c.moss}, 0.55);
      }

      tooltip {
        background: ${c.ink};
        border: 2px solid ${c.pink};
        border-radius: 8px;
      }
      tooltip label { color: ${c.text}; }

      #custom-glade-home, #custom-glade-apps, #custom-power,
      #taskbar button, #pulseaudio, #clock, #tray {
        margin: 5px 4px 6px 4px;
        padding: 0 12px;
        color: ${c.text};
        background: ${c.board};
        border: 2px solid ${c.ink};
        border-radius: 8px;
        box-shadow: 0 2px 0 ${c.ink};
      }

      /* the three big buttons each glow in their own colour */
      #custom-glade-home { color: ${c.moss}; border-color: alpha(${c.moss}, 0.7); margin-left: 10px; }
      #custom-glade-apps { color: ${c.violet}; border-color: alpha(${c.violet}, 0.7); }
      #custom-power      { color: ${c.pink}; border-color: alpha(${c.pink}, 0.7); margin-right: 10px; }

      #custom-glade-home:hover, #custom-glade-apps:hover, #custom-power:hover,
      #taskbar button:hover, #pulseaudio:hover, #clock:hover {
        color: #ffffff;
        background: ${c.boardHi};
        border-color: ${c.pink};
      }

      #taskbar button.active { background: ${c.boardHi}; border-color: ${c.pink}; }
      #taskbar button.minimized { opacity: 0.6; }

      #clock, #pulseaudio, #tray { color: ${c.amber}; }
    '';
  };
}
