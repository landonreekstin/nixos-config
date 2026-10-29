# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/dock.nix
#
# The glade's dock, a minimise button on every title bar, and new windows that take the
# keyboard as soon as they open (dock.py in github:cblaney00/glade, pkgs/glade, does all
# three). Asked for by insideabush: a Mac-style dock of his apps with a dot under each
# open one, along the bottom of the lower monitor so it doesn't cut across the path
# between the two screens.
{ config, pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";
  c = import ./colors.nix;
  glade = pkgs.callPackage ../../../../../pkgs/glade { };

  # Always in the dock, in this order (the apps the glade's boards open). Anything else
  # that is open joins on the end while it runs.
  favourites = [
    "kitty.desktop"
    "org.kde.dolphin.desktop"
    "org.chromium.Chromium.desktop"
    "com.discordapp.Discord.desktop"
    "spotify.desktop"
    "steam.desktop"
    # his own app (hosts/blaney-pc/home.nix); a favourite that isn't installed is skipped
    "f-117.desktop"
  ];


  # Glowing spirit-cloth like the glade's banners: see-through, lit softly from the top,
  # a thin rim of light, the icons floating on it.
  css = pkgs.writeText "glade-dock.css" ''
    window { background: transparent; }

    #dock {
      padding: 4px 8px 4px 8px;
      background: linear-gradient(to bottom, alpha(${c.violet}, 0.22), alpha(${c.night}, 0.35));
      border: 1px solid alpha(${c.violet}, 0.55);
      border-radius: 10px;
      box-shadow: 0 0 12px alpha(${c.violet}, 0.25);
    }

    #hint {
      color: alpha(${c.text}, 0.75);
      font-family: "${c.font}";
      font-size: 11px;
      padding: 0 4px 3px 4px;
    }

    button.app {
      padding: 4px 6px 2px 6px;
      background: none;
      border: 2px solid transparent;
      border-radius: 8px;
      box-shadow: none;
      outline: none;
      transition: background 300ms ease, border-color 300ms ease;
    }
    button.app:hover { background: alpha(${c.violet}, 0.22); border-color: alpha(${c.pink}, 0.7); }

    /* the open dot: a little square of glowing moss, dimmer while minimised */
    .dot { min-width: 6px; min-height: 6px; border-radius: 1px; }
    .dot.open { background: ${c.moss}; box-shadow: 0 0 6px ${c.moss}; }
    .dot.minimized { background: alpha(${c.moss}, 0.35); }

    tooltip, tooltip.background {
      background: ${c.ink};
      border: 2px solid ${c.pink};
      border-radius: 8px;
    }
    tooltip label, menu, menuitem {
      color: ${c.text};
      font-family: "${c.font}";
      font-size: 14px;
    }
    menu {
      background: ${c.night};
      border: 2px solid ${c.pink};
      border-radius: 8px;
      padding: 4px;
    }
    menuitem { padding: 6px 12px; border-radius: 6px; }
    menuitem:hover { background: ${c.boardHi}; }
  '';

  # Kept up like the glade: if the dock ever exits it comes back after a moment.
  dockLoop = pkgs.writeShellScript "glade-dock-loop" ''
    while true; do
      ${glade}/bin/glade-dock ${lib.escapeShellArg (builtins.toJSON favourites)} ${css} \
        > "''${XDG_RUNTIME_DIR:-/tmp}/glade-dock.log" 2>&1
      sleep 2
    done
  '';
  watchLoop = pkgs.writeShellScript "glade-windows-loop" ''
    while true; do
      ${glade}/bin/glade-dock watch > "''${XDG_RUNTIME_DIR:-/tmp}/glade-windows.log" 2>&1
      sleep 2
    done
  '';
in
{
  config = lib.mkIf desktop.enabled {
    # glade-dock itself is on the PATH with the glade (desktop.nix), for the title bars'
    # minimise button there.
    hyprDesktops.glade.extraConfig = ''
      exec-once = ${dockLoop}
      exec-once = ${watchLoop}
    '';
  };
}
