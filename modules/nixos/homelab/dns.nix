# ~/nixos-config/modules/nixos/homelab/dns.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.dns;
in
{
  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        server = {
          interface = [ "0.0.0.0" ];
          access-control = [
            "127.0.0.0/8 allow"
            "192.168.1.0/24 allow"
            "192.168.100.0/24 allow"
            "10.0.0.0/8 allow"
          ];
          local-zone = [ ''"lan." static'' ];
          local-data = [
            # optiplex-nas
            ''"nas.lan. A 192.168.1.76"''
            ''"jellyfin.lan. A 192.168.1.76"''
            ''"jellyseerr.lan. A 192.168.1.76"''
            ''"transmission.lan. A 192.168.1.76"''
            ''"radarr.lan. A 192.168.1.76"''
            ''"sonarr.lan. A 192.168.1.76"''
            ''"bazarr.lan. A 192.168.1.76"''
            ''"prowlarr.lan. A 192.168.1.76"''
            ''"nix-cache.lan. A 192.168.1.76"''
            # mini-server
            ''"mini.lan. A 192.168.100.103"''
            ''"homeassistant.lan. A 192.168.100.103"''
            ''"vaultwarden.lan. A 192.168.100.103"''
            ''"dashboard.lan. A 192.168.100.103"''
          ];
        };
        forward-zone = [
          {
            name = ".";
            forward-tls-upstream = "yes";
            forward-addr = [
              "1.1.1.1@853#cloudflare-dns.com"
              "1.0.0.1@853#cloudflare-dns.com"
              "9.9.9.9@853#dns.quad9.net"
            ];
          }
        ];
      };
    };

    # optiplex-nas uses its own Unbound instance for name resolution
    networking.nameservers = lib.mkForce [ "127.0.0.1" ];

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
