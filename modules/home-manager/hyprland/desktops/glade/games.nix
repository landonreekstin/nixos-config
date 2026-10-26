# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/games.nix
#
# The Games tab on the glade's bar (games.py): every game on the computer as box art —
# Steam, Heroic (Epic, GOG), Lutris (the EA app), other installed games, and emulator
# games in ~/Games/ROMs — most recently played first. Asked for by insideabush; clicking a
# game starts its launcher and then the game.
{ config, pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";
  c = import ./colors.nix;

  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  gladeGames = pkgs.stdenv.mkDerivation {
    name = "glade-games";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk3 pkgs.gtk-layer-shell pkgs.librsvg pyEnv ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      { echo '#!${pyEnv}/bin/python3'; cat ${./games.py}; } > $out/bin/.glade-games
      chmod +x $out/bin/.glade-games
      runHook postInstall
    '';
    # the stylesheet is passed in, so the panel is made of the same night and boards as the bar
    postFixup = ''
      makeWrapper $out/bin/.glade-games $out/bin/glade-games "''${gappsWrapperArgs[@]}" --add-flags ${css}
    '';
    dontWrapGApps = true;
  };

  css = pkgs.writeText "glade-games.css" ''
    #backdrop { background: alpha(${c.night}, 0.0); transition: background 260ms ease-in-out 60ms; }
    #backdrop.shown { background: alpha(${c.night}, 0.55); }
    #panel {
      opacity: 0;
      transition: opacity 260ms ease-in-out 60ms;
      padding: 16px 18px 10px 18px;
      background: ${c.night};
      border: 2px solid ${c.ink};
      border-radius: 12px;
      box-shadow: 0 0 0 2px alpha(${c.violet}, 0.6), 0 4px 0 ${c.ink};
      font-family: "${c.font}", "Noto Color Emoji", sans-serif;
      color: ${c.text};
    }
    #backdrop.shown #panel { opacity: 1; }
    #title { color: ${c.amber}; font-size: 20px; }
    #count, #hint { color: alpha(${c.text}, 0.6); font-size: 12px; }
    entry {
      background: ${c.board}; color: ${c.text}; caret-color: ${c.moss};
      border: 2px solid ${c.ink}; border-radius: 8px; box-shadow: none; padding: 4px 8px;
    }
    entry:focus { border-color: ${c.violet}; }
    scrolledwindow, viewport, flowbox, flowboxchild { background: transparent; }
    flowboxchild { padding: 0; }
    button.game {
      padding: 6px; background: transparent; border: 2px solid transparent; border-radius: 10px;
      transition: background 180ms ease-in-out, border-color 180ms ease-in-out;
    }
    button.game:hover { background: ${c.board}; border-color: ${c.pink}; }
    button.game.launching { background: ${c.boardHi}; border-color: ${c.moss}; }
    .art { background: ${c.board}; border-radius: 6px; }
    .initial { color: alpha(${c.text}, 0.35); font-size: 48px; }
    .name { color: ${c.text}; font-size: 13px; }
    button.game:hover .name { color: #ffffff; }
    .badge {
      margin: 4px; padding: 0 5px; font-size: 10px; border-radius: 5px;
      background: alpha(${c.ink}, 0.85); color: ${c.text};
    }
    .b-steam { color: ${c.cyan}; }
    .b-epic, .b-gog { color: ${c.violet}; }
    .b-ea { color: ${c.pink}; }
    .b-ds, .b-gba, .b-gbc, .b-gb, .b-gcwii, .b-gc, .b-wii { color: ${c.amber}; }
    .b-pc, .b-lutris { color: ${c.moss}; }
  '';
in
{
  config = lib.mkIf desktop.enabled {
    home.packages = [ gladeGames ];
    # emulator games live here (he chose one folder over searching everywhere)
    home.file."Games/ROMs/.keep".text = "";
  };
}
