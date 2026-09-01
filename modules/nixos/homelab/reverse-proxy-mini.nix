# ~/nixos-config/modules/nixos/homelab/reverse-proxy-mini.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab;
  # When localCA is enabled, vhosts get HTTPS via ACME; otherwise plain HTTP.
  mkProxy = port: {
    enableACME = cfg.localCA.enable;
    forceSSL = cfg.localCA.enable;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
in
{
  config = lib.mkIf cfg.reverseProxy.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      virtualHosts = lib.mkMerge [
        (lib.mkIf cfg.homeAssistant.enable { "homeassistant.lan" = mkProxy cfg.homeAssistant.port; })
        (lib.mkIf cfg.vaultwarden.enable   { "vaultwarden.lan"   = mkProxy cfg.vaultwarden.port; })
        (lib.mkIf cfg.gameControl.enable   { "dashboard.lan"     = mkProxy cfg.gameControl.port; })
      ];
    };

    # HA http config (trusted_proxies, use_x_forwarded_for) is now managed in the UI
    # under Settings > System > Network — HA 2026.x deprecated the YAML `http:` block
    # and auto-imports the previous values into .storage/http on first migration.

    networking.firewall.allowedTCPPorts = [ 80 ] ++ lib.optionals cfg.localCA.enable [ 443 ];
  };
}
