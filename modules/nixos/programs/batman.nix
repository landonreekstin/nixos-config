# ~/nixos-config/modules/nixos/programs/batman.nix
{ config, pkgs, lib, ... }:

# The Batman (JAKKS Pacific TV game, 2004) running natively, with two-player co-op on one
# PC and online: Batman is player 1, Robin player 2. The game is pkgs/batman, built from
# github.com/landonreekstin/jakks-batman-recomp.
#
# One command, `batman`, plus a start-menu entry for each way to play:
#
#   batman            one player (Batman)
#   batman coop       two players on this PC (P2: W A S D, J K L, P, or a second controller)
#   batman host       host an online game; player 2 joins it
#   batman join [IP]  join the game hosted at IP (default: joinAddress)
#
# The ROM is not packaged. On first run the launcher downloads it from the NAS's public
# drop (customConfig.homelab.publicFiles; reachable from every homelab VPN peer, port 80
# on 192.168.1.76), checks its SHA-256 and keeps it in ~/.local/share/batman, where the
# save file, save states and screenshots go too. Robin's sprites are generated from the
# ROM there, again whenever the package changes.
#
# Online: the host listens on TCP and UDP port 7845. Restricted VPN peers (Blaney) can only
# reach 192.168.1.76, so optiplex-fw forwards 192.168.1.76:7845 from wg0 to gaming-pc's
# wg-nas address 10.10.0.11 (pf.conf in openbsd-dotfiles, "The Batman netplay"), and
# gaming-pc's wg-nas routes the VPN subnet so the replies go back the same way. Both
# players must run the same build, so hosts that play together need the same pin.
let
  cfg = config.customConfig.programs.batman;
  batman = pkgs.callPackage ../../../pkgs/batman { };
  port = 7845;

  launcher = pkgs.writeShellApplication {
    name = "batman";
    runtimeInputs = [ pkgs.curl pkgs.coreutils pkgs.python3 pkgs.zenity ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/batman"
      rom="$data/batman.bin"
      sha=${cfg.romSha256}
      url=${lib.escapeShellArg cfg.romUrl}
      mkdir -p "$data/mods"

      # errors go to a dialog too: from the start menu there is no terminal to read them in
      fail() {
        echo "batman: $1" >&2
        zenity --error --title="The Batman" --width=440 --text="$1" 2>/dev/null || true
        exit 1
      }
      rom_ok() { [ -f "$rom" ] && [ "$(sha256sum "$rom" | cut -d' ' -f1)" = "$sha" ]; }

      if ! rom_ok; then
        rm -f "$rom.part" "$rom.rc"
        { curl -fsSL --connect-timeout 8 --max-time 300 -o "$rom.part" "$url"; echo $? > "$rom.rc"; } |
          zenity --progress --pulsate --auto-close --no-cancel --title="The Batman" \
            --text="Downloading the game from the homelab (first run only)..." 2>/dev/null || true
        if [ "$(cat "$rom.rc" 2>/dev/null)" != 0 ] || [ "$(sha256sum "$rom.part" | cut -d' ' -f1)" != "$sha" ]; then
          rm -f "$rom.part" "$rom.rc"
          fail "Couldn't download the game from the homelab.

      Turn on the homelab VPN (the network icon in the taskbar, then homelab-vpn) and try again."
        fi
        mv "$rom.part" "$rom"
        rm -f "$rom.rc"
      fi

      # Robin's sprites are made from the ROM: once per version of the game
      if [ "$(cat "$data/mods/.made-by" 2>/dev/null)" != "${batman}" ]; then
        for mod in robin robin-p2; do
          mkdir -p "$data/mods/$mod"
          PYTHONDONTWRITEBYTECODE=1 python3 "${batman}/share/batman/mods/$mod/generate.py" "$rom" \
            > "$data/mods/$mod/mod.txt.new" 2>/dev/null || fail "Couldn't make Robin's sprites."
          mv "$data/mods/$mod/mod.txt.new" "$data/mods/$mod/mod.txt"
        done
        echo "${batman}" > "$data/mods/.made-by"
      fi

      mode="''${1:-play}"
      args=()
      case "$mode" in
        play) ;;
        robin) args=(--mods robin) ;;
        coop) args=(--coop --mods robin-p2) ;;
        host) args=(--mods robin-p2 --host ${toString port}) ;;
        join) args=(--mods robin-p2 --join "''${2:-${cfg.joinAddress}}") ;;
        *)
          echo "usage: batman [play | robin | coop | host | join [address]]" >&2
          exit 2 ;;
      esac

      # LD_LIBRARY_PATH from a dev shell can break SDL; the game finds its own libraries
      unset LD_LIBRARY_PATH
      cd "$data"
      if ! "${batman}/libexec/batman/batman" "$rom" --save "$data/batman.sav" --mods-dir "$data/mods" \
          "''${args[@]}" 2> >(tee "$data/last.log" >&2); then
        fail "The game stopped with an error:

      $(tail -n 5 "$data/last.log")"
      fi
    '';
  };

  entry = name: desktopName: comment: exec: pkgs.makeDesktopItem {
    inherit name desktopName comment exec;
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" "ActionGame" ];
    keywords = [ "batman" "robin" "jakks" "co-op" ];
  };
in
{
  options.customConfig.programs.batman = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install The Batman (JAKKS TV game, native) with the `batman` launcher and start-menu
        entries for one player, two players on this PC, and joining an online game.
      '';
    };
    host = mkOption {
      type = types.bool;
      default = false;
      description = ''
        This machine hosts online games: adds the "Host Online Game" entry and opens TCP and
        UDP port ${toString port} on hostInterfaces.
      '';
    };
    hostInterfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "wg-nas" ];
      description = "Interfaces players join through (gaming-pc: wg-nas, which optiplex-fw forwards to).";
    };
    joinAddress = mkOption {
      type = types.str;
      default = "192.168.1.76";
      description = ''
        Where "Join Online Game" connects: optiplex-fw forwards port ${toString port} on the
        legacy NAS address (the one address restricted VPN peers route) to gaming-pc.
      '';
    };
    romUrl = mkOption {
      type = types.str;
      default = "http://192.168.1.76/public/batman/batman.bin";
      description = "Where the launcher downloads the ROM on first run (the NAS public drop).";
    };
    romSha256 = mkOption {
      type = types.str;
      default = "4ec5438d16e222cc624820f45579071b8f8a4e91c65ae76e5425565509271766";
      description = "SHA-256 of the ROM (MAME set jak_batm).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      launcher
      (entry "batman" "The Batman" "Batman, one player" "batman")
      (entry "batman-coop" "The Batman: Two Players" "Batman and Robin on this PC" "batman coop")
      (entry "batman-join" "The Batman: Join Online Game" "Play Robin in Lando's game" "batman join")
    ] ++ lib.optional cfg.host
      (entry "batman-host" "The Batman: Host Online Game" "Play Batman; player 2 joins over the VPN" "batman host");

    networking.firewall.interfaces = lib.mkIf cfg.host (lib.genAttrs cfg.hostInterfaces (_: {
      allowedTCPPorts = [ port ];
      allowedUDPPorts = [ port ];
    }));
  };
}
