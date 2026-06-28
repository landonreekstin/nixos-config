# ~/nixos-config/modules/nixos/homelab/reverse-proxy-nas.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab;
  mkProxy = port: {
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
        (lib.mkIf cfg.jellyfin.enable     { "jellyfin.lan"     = mkProxy 8096; })
        (lib.mkIf cfg.jellyseerr.enable   { "jellyseerr.lan"   = mkProxy 5055; })
        (lib.mkIf cfg.transmission.enable { "transmission.lan" = mkProxy 9091; })
        (lib.mkIf cfg.arr.radarr.enable   { "radarr.lan"       = mkProxy 7878; })
        (lib.mkIf cfg.arr.sonarr.enable   { "sonarr.lan"       = mkProxy 8989; })
        (lib.mkIf cfg.arr.bazarr.enable   { "bazarr.lan"       = mkProxy 6767; })
        (lib.mkIf cfg.arr.prowlarr.enable { "prowlarr.lan"     = mkProxy 9696; })
        (lib.mkIf cfg.nixCache.enable     { "nix-cache.lan"    = mkProxy 5000; })
      ];
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
