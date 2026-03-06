# ~/nixos-config/modules/nixos/common/networking.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.networking;

  resolverServers = {
    cloudflare = [ "cloudflare" ];
    quad9      = [ "quad9-doh-ip4-filter-pri" ];
    mullvad    = [ "mullvad-doh" ];
  };
in
{
  networking.hostName = config.customConfig.system.hostName;

  # Enable NetworkManager
  networking.networkmanager.enable = cfg.networkmanager.enable;

  networking.interfaces = lib.mkMerge [
    (lib.mkIf cfg.staticIP.enable {
      ${cfg.staticIP.interface} = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = cfg.staticIP.address;
          prefixLength = 24;
        } ];
      };
    })
    (lib.mkIf (cfg.wakeOnLan.enable && cfg.wakeOnLan.interface != null) {
      ${cfg.wakeOnLan.interface}.wakeOnLan.enable = true;
    })
  ];

  networking.defaultGateway = if cfg.staticIP.enable then cfg.staticIP.gateway else null;
  networking.nameservers = lib.mkMerge [
    (lib.mkIf cfg.staticIP.enable [
      cfg.staticIP.gateway
      "1.1.1.1"
      "8.8.8.8"
    ])
    (lib.mkIf cfg.encryptedDns.enable [ "127.0.0.1" "::1" ])
  ];

  # When encrypted DNS is enabled, stop NetworkManager from overriding resolv.conf
  # so dnscrypt-proxy2 (listening on 127.0.0.1:53) is used exclusively.
  networking.networkmanager.dns = lib.mkIf cfg.encryptedDns.enable "none";

  services.dnscrypt-proxy2 = lib.mkIf cfg.encryptedDns.enable {
    enable = true;
    settings = {
      server_names = resolverServers.${cfg.encryptedDns.resolver};
      listen_addresses = [ "127.0.0.1:53" "::1:53" ];
      require_dnssec = false;
      require_nolog = true;
      require_nofilter = false;
    };
  };

  networking.firewall.enable = cfg.firewall.enable;
}
