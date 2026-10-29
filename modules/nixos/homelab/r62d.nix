# ~/nixos-config/modules/nixos/homelab/r62d.nix
# R62D, insideabush's tactical 5v5 browser game (pkgs/r62d, companion repo cblaney00/r62d),
# as an always-on server so every VPN player joins the same lobby. One process serves the
# pages and the WebSocket on one port. Profiles and match history live in /var/lib/r62d.
# Players reach it at http://192.168.1.76:6262: optiplex-fw redirects that alias's port to
# this host (docs/networking.md "R62D").
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.r62d;
  pkg = pkgs.callPackage ../../../pkgs/r62d { };
in
{
  options.customConfig.homelab.r62d = with lib; {
    enable = mkEnableOption "R62D game server";
    port = mkOption {
      type = types.port;
      default = 6262;
      description = "Port the game listens on (pages and WebSocket).";
    };
    publicUrl = mkOption {
      type = types.str;
      default = "http://192.168.1.76:${toString cfg.port}";
      description = ''
        The address players type, shown in the lobby ("Friends join at ..."). The server only
        knows its own interfaces (192.168.100.103 here, which no player can reach), so it is
        passed in as R62D_PUBLIC_URL. Older r62d builds ignore it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.r62d = {
      description = "R62D game server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = toString cfg.port;
        R62D_DATA = "/var/lib/r62d";
        R62D_PUBLIC_URL = cfg.publicUrl;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkg}/bin/r62d-server";
        DynamicUser = true;
        StateDirectory = "r62d";
        Restart = "on-failure";
        SyslogIdentifier = "r62d";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
