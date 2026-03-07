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
    # mkForce so this wins over the static IP entry if both are enabled
    (lib.mkIf cfg.encryptedDns.enable (lib.mkForce [ "127.0.0.1" ]))
  ];

  networking.firewall.enable = cfg.firewall.enable;

  # Encrypted DNS: dnscrypt-proxy on 127.0.0.1:53.
  # The NixOS module already grants CAP_NET_BIND_SERVICE so port 53 binding works.
  # NM dns=none stops it from overwriting /etc/resolv.conf with DHCP-provided DNS.
  # networking.nameservers writes 127.0.0.1 to resolv.conf via NixOS activation.
  services.dnscrypt-proxy = lib.mkIf cfg.encryptedDns.enable {
    enable = true;
    settings = {
      server_names = resolverServers.${cfg.encryptedDns.resolver};
      listen_addresses = [ "127.0.0.1:53" ];
      require_dnssec = false;
      require_nolog = true;
      require_nofilter = false;
    };
  };

  networking.networkmanager.dns = lib.mkIf cfg.encryptedDns.enable (lib.mkForce "none");
}
