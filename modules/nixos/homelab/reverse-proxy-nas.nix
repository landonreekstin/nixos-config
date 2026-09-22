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
        (lib.mkIf cfg.arr.lidarr.enable   { "lidarr.lan"       = mkProxy 8686; })
        (lib.mkIf cfg.navidrome.enable    { "music.lan"        = mkProxy cfg.navidrome.port; })
        (lib.mkIf cfg.ombi.enable         { "ombi.lan"         = mkProxy cfg.ombi.port; })
        (lib.mkIf cfg.slskd.enable        { "slskd.lan"        = mkProxy cfg.slskd.webPort; })
        (lib.mkIf cfg.soularr.enable      { "soularr.lan"      = mkProxy cfg.soularr.webPort; })
        (lib.mkIf cfg.gamarr.enable       { "gamarr.lan"       = mkProxy cfg.gamarr.port; })
        (lib.mkIf cfg.nixCache.enable     { "nix-cache.lan"    = mkProxy 5000; })
      ];
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
