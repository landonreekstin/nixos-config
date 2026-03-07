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
  networking.nameservers = lib.mkIf cfg.staticIP.enable [
    cfg.staticIP.gateway
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.firewall.enable = cfg.firewall.enable;

  # Encrypted DNS: dnscrypt-proxy on unprivileged port 5335, systemd-resolved as intermediary.
  # systemd-resolved listens on 127.0.0.53:53 and forwards upstream queries to dnscrypt-proxy.
  # NetworkManager uses systemd-resolved so /etc/resolv.conf points to 127.0.0.53.
  services.dnscrypt-proxy = lib.mkIf cfg.encryptedDns.enable {
    enable = true;
    settings = {
      server_names = resolverServers.${cfg.encryptedDns.resolver};
      listen_addresses = [ "127.0.0.1:5335" ];
      require_dnssec = false;
      require_nolog = true;
      require_nofilter = false;
    };
  };

  services.resolved = lib.mkIf cfg.encryptedDns.enable {
    enable = true;
    extraConfig = ''
      DNS=127.0.0.1:5335
      FallbackDNS=
    '';
  };

  # "none" stops NM from pushing per-link DNS (from DHCP) to systemd-resolved.
  # Without this, the router's DNS (192.168.1.1) would take per-link precedence
  # over the global dnscrypt-proxy config. systemd-resolved still manages
  # /etc/resolv.conf via its stub listener (127.0.0.53).
  networking.networkmanager.dns = lib.mkIf cfg.encryptedDns.enable (lib.mkForce "none");
}
