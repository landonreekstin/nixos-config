# ~/nixos-config/modules/nixos/homelab/vaultwarden.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.vaultwarden;
in
{
  config = lib.mkIf cfg.enable {

    services.vaultwarden = {
      enable = true;
      config = {
        # When TLS/Caddy is active, use https and bind to localhost only.
        # When accessing directly (no Caddy), use http and bind to all interfaces.
        DOMAIN = if cfg.tls.enable then "https://${cfg.domain}" else "http://${cfg.domain}";
        ROCKET_PORT = cfg.port;
        ROCKET_ADDRESS = if cfg.tls.enable then "127.0.0.1" else "0.0.0.0";
        SIGNUPS_ALLOWED = cfg.signupsAllowed;
      };
      # File must contain at least: ADMIN_TOKEN=<hashed-token>
      # Generate with: echo -n "your-token" | argon2 somesalt -id -t 3 -m 16 -p 4 -l 32 -e
      # Or use the simpler but less secure: ADMIN_TOKEN=<plaintext>
      # Optional extras: SMTP_HOST, SMTP_FROM, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
      environmentFile = cfg.environmentFile;
    };

    # Caddy handles TLS termination and reverse proxies to Vaultwarden
    services.caddy = lib.mkIf cfg.tls.enable {
      enable = true;
      virtualHosts."${cfg.domain}".extraConfig = ''
        reverse_proxy localhost:${toString cfg.port}
      '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.tls.enable [ 80 443 ];

  };
}
