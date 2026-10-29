# ~/nixos-config/modules/nixos/programs/steel-horizon.nix
{ config, pkgs, lib, ... }:

# Steel Horizon RTS: a native real-time naval battle game built around the battle layer
# of Steel Horizon (PSP, 2007). The engine is pkgs/steel-horizon, built from
# github.com/landonreekstin/steel-horizon-recomp; it loads the original game's models,
# textures, sound and ship data at runtime.
#
# One command, `steel-horizon`, plus a start-menu entry:
#
#   steel-horizon               the game's menu: tutorial, skirmish, custom battle, online
#   steel-horizon --standalone  no game files: built-in ship data and generated models
#   (any other arguments go to the engine; `steel-horizon --help` is not one of them)
#
# The ISO is not packaged. On first run the launcher downloads it from the NAS's public
# drop (customConfig.homelab.publicFiles; reachable from every homelab VPN peer, port 80
# on 192.168.1.76), checks its SHA-256 and keeps it in ~/.local/share/steel-horizon. The
# engine's asset folder (assets/: files, data, music) is made from it there, again
# whenever the package changes.
#
# Online play (Host / Join in the game's menu, TCP port 47800 by default) works on a LAN;
# over the VPN it would need a forward like The Batman's (docs/networking.md), which
# isn't set up.
let
  cfg = config.customConfig.programs.steel-horizon;
  game = pkgs.callPackage ../../../pkgs/steel-horizon { };
  tools = "${game}/share/steel-horizon/tools";

  launcher = pkgs.writeShellApplication {
    name = "steel-horizon";
    runtimeInputs = [ pkgs.curl pkgs.coreutils pkgs.python3 pkgs._7zz pkgs.ffmpeg-headless pkgs.zenity ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/steel-horizon"
      iso="$data/steel-horizon.iso"
      assets="$data/assets"
      sha=${cfg.isoSha256}
      url=${lib.escapeShellArg cfg.isoUrl}
      mkdir -p "$data"

      # errors go to a dialog too: from the start menu there is no terminal to read them in
      fail() {
        echo "steel-horizon: $1" >&2
        zenity --error --title="Steel Horizon" --width=440 --text="$1" 2>/dev/null || true
        exit 1
      }
      iso_ok() { [ -f "$iso" ] && [ "$(sha256sum "$iso" | cut -d' ' -f1)" = "$sha" ]; }

      standalone=0
      for a in "$@"; do [ "$a" = --standalone ] && standalone=1; done

      if [ "$standalone" = 0 ] && ! iso_ok; then
        rm -f "$iso.part" "$iso.rc"
        { if curl -fsSL --connect-timeout 8 --max-time 900 -o "$iso.part" "$url"; then echo 0; else echo 1; fi > "$iso.rc"; } |
          zenity --progress --pulsate --auto-close --no-cancel --title="Steel Horizon" \
            --text="Downloading the game from the homelab (first run only)..." 2>/dev/null || true
        if [ "$(cat "$iso.rc" 2>/dev/null)" != 0 ] || [ "$(sha256sum "$iso.part" | cut -d' ' -f1)" != "$sha" ]; then
          rm -f "$iso.part" "$iso.rc"
          fail "Couldn't download the game from the homelab.

      Turn on the homelab VPN (the network icon in the taskbar, then homelab-vpn) and try again."
        fi
        mv "$iso.part" "$iso"
        rm -f "$iso.rc"
      fi

      # The asset folder is made from the ISO: once per version of the game
      if [ "$standalone" = 0 ] && [ "$(cat "$assets/.made-by" 2>/dev/null)" != "${game}" ]; then
        work="$data/extract"
        rm -rf "$work" "$assets.new"
        # explicit && chain: set -e doesn't apply inside an `if` condition
        make_assets() {
          local usr="$work/PSP_GAME/USRDIR"
          7zz x -bd -y -o"$work" "$iso" PSP_GAME/USRDIR > /dev/null &&
            python3 -I ${tools}/imp_extract.py "$usr/GAMEDATA.XML" "$usr/GAMEDATA.IMP" "$assets.new/files" &&
            python3 -I ${tools}/data2json.py "$assets.new/files" "$assets.new/data" &&
            python3 -I ${tools}/at3wav.py "$assets.new/files/sound/music" "$assets.new/music"
        }
        { if make_assets > "$data/extract.log" 2>&1; then echo 0; else echo 1; fi > "$data/extract.rc"; } |
          zenity --progress --pulsate --auto-close --no-cancel --title="Steel Horizon" \
            --text="Unpacking the game's ships, sound and music (first run only)..." 2>/dev/null || true
        rm -rf "$work"
        if [ "$(cat "$data/extract.rc" 2>/dev/null)" != 0 ]; then
          rm -rf "$assets.new"
          fail "Couldn't unpack the game files:

      $(tail -n 5 "$data/extract.log")"
        fi
        rm -f "$data/extract.rc"
        echo "${game}" > "$assets.new/.made-by"
        rm -rf "$assets"
        mv "$assets.new" "$assets"
      fi

      # LD_LIBRARY_PATH from a dev shell can break SDL; the game finds its own libraries
      unset LD_LIBRARY_PATH
      cd "$data"
      args=(--assets "$assets")
      [ "$standalone" = 1 ] && args=()
      if ! "${game}/libexec/steel-horizon/bin/shrts" "''${args[@]}" "$@" 2> >(tee "$data/last.log" >&2); then
        fail "The game stopped with an error:

      $(tail -n 5 "$data/last.log")"
      fi
    '';
  };

  entry = pkgs.makeDesktopItem {
    name = "steel-horizon";
    desktopName = "Steel Horizon";
    comment = "Real-time naval battles: tutorial, skirmish and custom battles";
    exec = "steel-horizon";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" "StrategyGame" ];
    keywords = [ "naval" "battleship" "rts" "strategy" ];
  };
in
{
  options.customConfig.programs.steel-horizon = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install Steel Horizon RTS (a native naval battle game on the PSP game's assets)
        with the `steel-horizon` launcher and a start-menu entry.
      '';
    };
    isoUrl = mkOption {
      type = types.str;
      default = "http://192.168.1.76/public/steel-horizon/steel-horizon.iso";
      description = "Where the launcher downloads the ISO on first run (the NAS public drop).";
    };
    isoSha256 = mkOption {
      type = types.str;
      default = "6e00ac4ba1f91385b8065c5be142fa73d45a2d58b45aae2cc18634c02d7b3e9c";
      description = "SHA-256 of Steel Horizon (USA).iso.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ launcher entry ];
  };
}
