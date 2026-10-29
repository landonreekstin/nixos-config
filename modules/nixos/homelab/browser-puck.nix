# ~/nixos-config/modules/nixos/homelab/browser-puck.nix
# browser-puck, the team air-hockey browser game (companion repo landonreekstin/browser-puck).
# One process serves the web client and its WebSocket on one port; rooms live in memory.
# Players reach it at http://192.168.1.76:8787: optiplex-fw redirects that alias's port to
# this host (docs/networking.md "browser-puck").
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.browserPuck;
  pkg = pkgs.callPackage ../../../pkgs/browser-puck { };
in
{
  options.customConfig.homelab.browserPuck = with lib; {
    enable = mkEnableOption "browser-puck game server";
    port = mkOption {
      type = types.port;
      default = 8787;
      description = "Port the game listens on (page and WebSocket).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.browser-puck = {
      description = "browser-puck game server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = toString cfg.port;
        HOST = "0.0.0.0";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkg}/bin/browser-puck";
        DynamicUser = true;
        Restart = "on-failure";
        SyslogIdentifier = "browser-puck";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
