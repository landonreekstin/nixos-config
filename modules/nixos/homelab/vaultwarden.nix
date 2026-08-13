# ~/nixos-config/modules/nixos/homelab/vaultwarden.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.vaultwarden;
in
{
  options.customConfig.homelab.vaultwarden = with lib; {
    enable = mkEnableOption "Vaultwarden password manager server";
    port = mkOption {
      type = types.port;
      default = 8222;
      description = "Port for Vaultwarden to listen on.";
    };
  };

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
        DOMAIN = "https://vaultwarden.lan";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
