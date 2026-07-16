# ~/nixos-config/modules/nixos/homelab/reverse-proxy-nas.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab;
  # User-facing services: reachable by anyone who gets to nginx (LAN + any VPN peer).
  mkProxy = port: {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
  # Admin/management services: restricted at nginx (by source IP) to the Main LAN,
  # the server subnet, and full VPN peers. Restricted VPN peers (10.10.0.4-10) get a
  # 403 here even though pf lets them reach port 80 — pf can't filter by Host header,
  # so this per-vhost ACL is what keeps the *arr/Transmission/nix-cache admin panels
  # away from restricted users while still letting them use jellyfin/jellyseerr/reader.
  adminAcl = ''
    allow 127.0.0.1;
    allow 192.168.1.0/24;     # Main LAN
    allow 192.168.100.0/24;   # server subnet
    allow 10.10.0.2/32;       # gaming-pc (full peer)
    allow 10.10.0.3/32;       # phone (full peer)
    deny all;                 # restricted VPN peers and everything else
  '';
  mkAdminProxy = port: {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = adminAcl;
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
        # User-facing (open to restricted VPN peers too):
        (lib.mkIf cfg.jellyfin.enable     { "jellyfin.lan"     = mkProxy 8096; })
        (lib.mkIf cfg.jellyseerr.enable   { "jellyseerr.lan"   = mkProxy 5055; })
        # Admin/management (LAN + full peers only; restricted peers get 403):
        (lib.mkIf cfg.transmission.enable { "transmission.lan" = mkAdminProxy 9091; })
        (lib.mkIf cfg.arr.radarr.enable   { "radarr.lan"       = mkAdminProxy 7878; })
        (lib.mkIf cfg.arr.sonarr.enable   { "sonarr.lan"       = mkAdminProxy 8989; })
        (lib.mkIf cfg.arr.bazarr.enable   { "bazarr.lan"       = mkAdminProxy 6767; })
        (lib.mkIf cfg.arr.prowlarr.enable { "prowlarr.lan"     = mkAdminProxy 9696; })
        (lib.mkIf cfg.nixCache.enable     { "nix-cache.lan"    = mkAdminProxy 5000; })
      ];
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
