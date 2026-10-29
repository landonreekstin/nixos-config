# ~/nixos-config/modules/nixos/programs/sub-of-seas.nix
{ config, pkgs, lib, ... }:

# Sub of Seas: lando's co-op WWII submarine game (Godot 4.7, github.com/landonreekstin/sub-of-seas,
# private). One command, `sub-of-seas`, plus a start-menu entry "Sub of Seas".
#
# The game is not built here. It is one Godot pack (.pck) that lando publishes from the game
# repo with `tools/publish.sh` to the NAS public drop (customConfig.homelab.publicFiles,
# http://192.168.1.76/public/sub-of-seas/). The launcher checks the drop on every start and
# downloads a new pack when its SHA-256 changed, so new builds reach every player without a
# rebuild; offline, it runs the last pack it has. The pack runs on the same Godot as the
# gamedev setup (unstable.godot_4, 4.7.x): host and players must be on the same Godot and the
# same build, which the game checks when someone joins.
#
# Online: the host listens on UDP port 7845, the same port as The Batman's netplay, so the
# forward that already exists works: optiplex-fw forwards 192.168.1.76:7845 from wg0 to
# gaming-pc's wg-nas address (pf.conf in openbsd-dotfiles, "The Batman netplay"). Restricted
# VPN peers (Blaney) join 192.168.1.76, which the menu fills in. Don't run both games' online
# modes at once.
let
  cfg = config.customConfig.programs.sub-of-seas;
  port = 7845;
  godot = pkgs.unstable.godot_4;

  launcher = pkgs.writeShellApplication {
    name = "sub-of-seas";
    runtimeInputs = [ pkgs.curl pkgs.coreutils pkgs.zenity godot ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/sub-of-seas"
      pck="$data/sub-of-seas.pck"
      base=${lib.escapeShellArg cfg.dropUrl}
      mkdir -p "$data"

      # errors go to a dialog too: from the start menu there is no terminal to read them in
      fail() {
        echo "sub-of-seas: $1" >&2
        zenity --error --title="Sub of Seas" --width=440 --text="$1" 2>/dev/null || true
        exit 1
      }
      have() { [ -f "$pck" ] && [ "$(sha256sum "$pck" | cut -d' ' -f1)" = "$1" ]; }

      # The newest build, if the drop is reachable.
      want=$(curl -fsS --connect-timeout 5 --max-time 10 "$base/sub-of-seas.sha256" 2>/dev/null || true)
      if [ -n "$want" ] && ! have "$want"; then
        rm -f "$pck.part"
        curl -fsSL --connect-timeout 8 --max-time 300 -o "$pck.part" "$base/sub-of-seas.pck" 2>/dev/null || true
        if [ -f "$pck.part" ] && [ "$(sha256sum "$pck.part" | cut -d' ' -f1)" = "$want" ]; then
          mv "$pck.part" "$pck"
        else
          rm -f "$pck.part"
        fi
      fi
      if [ ! -f "$pck" ]; then
        fail "Couldn't download Sub of Seas from the homelab.

      Turn on the homelab VPN (the network icon in the taskbar, then homelab-vpn) and try again."
      fi

      exec godot --main-pack "$pck" -- --port ${toString port} --address ${lib.escapeShellArg cfg.joinAddress} "$@"
    '';
  };

  entry = pkgs.makeDesktopItem {
    name = "sub-of-seas";
    desktopName = "Sub of Seas";
    comment = "Co-op WWII submarine: host a patrol or join Lando's";
    exec = "sub-of-seas";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" "Simulation" ];
    keywords = [ "submarine" "co-op" "lando" ];
  };
in
{
  options.customConfig.programs.sub-of-seas = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install Sub of Seas: the `sub-of-seas` launcher and a start-menu entry.";
    };
    host = mkOption {
      type = types.bool;
      default = false;
      description = "This machine hosts patrols: opens UDP port ${toString port} on hostInterfaces.";
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
        The host address the join box starts with: optiplex-fw forwards port ${toString port}
        on the legacy NAS address (the one address restricted VPN peers route) to gaming-pc.
      '';
    };
    dropUrl = mkOption {
      type = types.str;
      default = "http://192.168.1.76/public/sub-of-seas";
      description = "Where the launcher looks for new builds (the NAS public drop).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ launcher entry ];
    networking.firewall.interfaces = lib.mkIf cfg.host (lib.genAttrs cfg.hostInterfaces (_: {
      allowedUDPPorts = [ port ];
    }));
  };
}
