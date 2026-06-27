# ~/nixos-config/modules/nixos/homelab/vaultwarden.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.vaultwarden;
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets."vaultwarden-admin-token" = {
      sopsFile = ../../../secrets/mini-server.yaml;
    };

    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      environmentFile = config.sops.secrets."vaultwarden-admin-token".path;
      config = {
        ROCKET_PORT = cfg.port;
        ROCKET_ADDRESS = "0.0.0.0";
        SIGNUPS_ALLOWED = false;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
