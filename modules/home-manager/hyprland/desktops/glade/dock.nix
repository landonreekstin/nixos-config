# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/dock.nix
#
# The glade's dock, a minimise button on every title bar, and new windows that take the
# keyboard as soon as they open (dock.py does all three). Asked for by insideabush: a
# Mac-style dock of his apps with a dot under each open one, along the bottom of the
# lower monitor so it doesn't cut across the path between the two screens.
{ config, pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";
  c = import ./colors.nix;

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

  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  gladeDock = pkgs.stdenv.mkDerivation {
    name = "glade-dock";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pkgs.gtk-layer-shell pyEnv ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      { echo '#!${pyEnv}/bin/python3'; sed 's|@gio@|${pkgs.glib.bin}/bin/gio|' ${./dock.py}; } > $out/bin/glade-dock
      chmod +x $out/bin/glade-dock
      runHook postInstall
    '';
  };

  # A wooden name board like the ones in the glade, the icons standing on it.
  css = pkgs.writeText "glade-dock.css" ''
    window { background: transparent; }

    #dock {
      padding: 6px 8px 4px 8px;
      background: ${c.board};
      border: 2px solid ${c.ink};
      border-radius: 10px;
      box-shadow: 0 3px 0 ${c.ink};
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
    button.app:hover { background: ${c.boardHi}; border-color: ${c.pink}; }

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
      ${gladeDock}/bin/glade-dock ${lib.escapeShellArg (builtins.toJSON favourites)} ${css} \
        > "''${XDG_RUNTIME_DIR:-/tmp}/glade-dock.log" 2>&1
      sleep 2
    done
  '';
  watchLoop = pkgs.writeShellScript "glade-windows-loop" ''
    while true; do
      ${gladeDock}/bin/glade-dock watch > "''${XDG_RUNTIME_DIR:-/tmp}/glade-windows.log" 2>&1
      sleep 2
    done
  '';
in
{
  config = lib.mkIf desktop.enabled {
    home.packages = [ gladeDock ];

    # The title bars' minimise button (glade-dock minimize) is with the others in
    # desktop.nix.
    hyprDesktops.glade.extraConfig = ''
      exec-once = ${dockLoop}
      exec-once = ${watchLoop}
    '';
  };
}
