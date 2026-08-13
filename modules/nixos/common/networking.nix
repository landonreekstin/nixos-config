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
  options.customConfig.networking = with lib; {
    networkmanager = {
      enable = mkOption {
        type = types.bool;
        default = true; # Default to true to use NetworkManager for most desktop setups
        description = "Whether to enable NetworkManager for handling network connections.";
      };
    };
    staticIP = {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for static IP setups
        description = "Whether to configure a static IP address.";
      };
      interface = mkOption {
        type = types.nullOr types.str;
        default = null; # No default, must be set if staticIP.enable is true
        description = "The network interface to configure with a static IP (e.g., 'enp3s0', 'wlp2s0').";
      };
      address = mkOption {
        type = types.nullOr types.str;
        default = null; # No default, must be set if staticIP.enable is true
        description = "The static IPv4 address to assign (e.g., '192.168.1.100')";
      };
      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The gateway for the static IP configuration.";
      };
    };
    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true; # Default to true to have basic firewall enabled
        description = "Whether to enable the NixOS firewall.";
      };
    };
    wakeOnLan = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Wake-on-LAN for the specified network interface.";
      };
      interface = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The network interface to enable Wake-on-LAN on (e.g., 'enp8s0').";
        example = "enp8s0";
      };
    };
    encryptedDns = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable encrypted DNS via dnscrypt-proxy2.";
      };
      resolver = mkOption {
        type = types.enum [ "cloudflare" "quad9" "mullvad" ];
        default = "cloudflare";
        description = "Which upstream DNS resolver to use. cloudflare = 1.1.1.1 (DoH), quad9 = filtered DoH, mullvad = privacy-focused DoH.";
      };
    };
    localDns = {
      server = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IP of a local DNS server (e.g. optiplex-nas at 192.168.1.76) to use as the system resolver instead of upstream or dnscrypt-proxy. When set, dnscrypt-proxy is skipped and this IP is written to resolv.conf.";
        example = "192.168.1.76";
      };
    };
  };

  config = {
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
      # localDns.server wins over everything (mkOverride 40 > mkForce's 50)
      (lib.mkIf (cfg.localDns.server != null) (lib.mkOverride 40 [ cfg.localDns.server ]))
    ];

    networking.firewall.enable = cfg.firewall.enable;

    # Encrypted DNS: dnscrypt-proxy on 127.0.0.1:53.
    # Skipped when localDns.server is set — the remote Unbound server handles upstream DoH instead.
    # NM dns=none stops it from overwriting /etc/resolv.conf with DHCP-provided DNS.
    # networking.nameservers writes 127.0.0.1 to resolv.conf via NixOS activation.
    services.dnscrypt-proxy = lib.mkIf (cfg.encryptedDns.enable && cfg.localDns.server == null) {
      enable = true;
      settings = {
        server_names = resolverServers.${cfg.encryptedDns.resolver};
        listen_addresses = [ "127.0.0.1:53" ];
        require_dnssec = false;
        require_nolog = true;
        require_nofilter = false;
      };
    };

    # Keep resolv.conf under our control when using either local encrypted DNS or a custom DNS server
    networking.networkmanager.dns = lib.mkIf (cfg.encryptedDns.enable || cfg.localDns.server != null) (lib.mkForce "none");
  };
}
