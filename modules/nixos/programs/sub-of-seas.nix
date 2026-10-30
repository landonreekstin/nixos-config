# ~/nixos-config/modules/nixos/programs/sub-of-seas.nix
{ config, pkgs, lib, ... }:

# Sub of Seas: lando's co-op WWII submarine game (Godot 4.7, github.com/landonreekstin/sub-of-seas).
# One command, `sub-of-seas`, plus a start-menu entry "Sub of Seas".
#
# The game is built from source on rebuild: pkgs/sub-of-seas pins the repo and exports it as
# one Godot pack (.pck), run on the same Godot as the gamedev setup (unstable.godot_4, 4.7.x).
# Host and players must be on the same Godot and the same build (the pin), which the game
# checks when someone joins, so a pin bump reaches every player on their next rebuild
# (docs/companion-repos.md).
#
# Online: the host listens on UDP port 7845, the same port as The Batman's netplay, so the
# forward that already exists works: optiplex-fw forwards 192.168.1.76:7845 from wg0 to
# gaming-pc's wg-nas address (pf.conf in openbsd-dotfiles, "The Batman netplay"). Restricted
# VPN peers (Blaney) join 192.168.1.76, which the menu fills in. Don't run both games' online
# modes at once.
let
  cfg = config.customConfig.programs.sub-of-seas;
  port = 7845;
  game = pkgs.callPackage ../../../pkgs/sub-of-seas { godot = pkgs.unstable.godot_4; };

  launcher = pkgs.writeShellScriptBin "sub-of-seas" ''
    exec ${lib.getExe game} -- --port ${toString port} --address ${lib.escapeShellArg cfg.joinAddress} "$@"
  '';

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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ launcher entry ];
    networking.firewall.interfaces = lib.mkIf cfg.host (lib.genAttrs cfg.hostInterfaces (_: {
      allowedUDPPorts = [ port ];
    }));
  };
}
