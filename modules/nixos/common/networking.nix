# ~/nixos-config/modules/nixos/common/networking.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.networking;

  resolverServers = {
    cloudflare = [ "cloudflare" ];
    quad9      = [ "quad9-doh-ip4-filter-pri" ];
    mullvad    = [ "mullvad-doh" ];
  };

  # The resolver this host would use if nothing else were available. Exactly one
  # of these applies; the ladder replaces an earlier mkMerge/mkOverride stack whose
  # highest-priority branch emitted a SINGLE-entry list. When optiplex-nas went down
  # that left /etc/resolv.conf holding only `nameserver 192.168.1.76`, so every
  # lookup on the host failed — including cache.nixos.org, which made it impossible
  # to rebuild out of the problem. Fallbacks are now appended unconditionally.
  primaryNameservers =
    if cfg.localDns.server != null  then [ cfg.localDns.server ]
    else if cfg.encryptedDns.enable then [ "127.0.0.1" ]
    else if cfg.staticIP.enable     then [ cfg.staticIP.gateway ]
    else [];

  # On systemd-resolved hosts the LAN resolver is attached to the NetworkManager
  # link and scoped to the `lan` routing domain, so the *global* scope carries the
  # public fallbacks only — a dead LAN resolver then cannot affect general lookups
  # at all. Without resolved there is only one scope, so the LAN resolver leads and
  # the fallbacks sit behind it.
  globalNameservers = lib.unique (
    if cfg.useResolved && cfg.localDns.server != null
    then cfg.fallbackDns
    else primaryNameservers ++ cfg.fallbackDns
  );
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
        description = ''
          IP of a local DNS server (e.g. optiplex-nas at 192.168.1.76) to use as this
          host's resolver for LAN names. Never the *only* resolver: fallbackDns is always
          configured alongside it, and on useResolved hosts this server is scoped to the
          `lan` domain so an outage cannot affect any other lookup.
        '';
        example = "192.168.1.76";
      };
    };
    fallbackDns = mkOption {
      type = types.listOf types.str;
      default = [ "1.1.1.1" "9.9.9.9" ];
      description = ''
        Public resolvers always configured alongside the LAN/encrypted resolver, so that
        losing the LAN resolver degrades name resolution instead of destroying it.
      '';
    };
    useResolved = mkOption {
      type = types.bool;
      default = cfg.networkmanager.enable;
      defaultText = lib.literalExpression "config.customConfig.networking.networkmanager.enable";
      description = ''
        Use systemd-resolved rather than the plain resolvconf path.

        Worth it on NetworkManager hosts: resolved gives real per-domain routing (the LAN
        resolver can own `lan` and nothing else), a FallbackDNS tier, and per-server
        failure tracking, so a dead resolver is noticed once instead of costing a timeout
        on every single lookup the way glibc's stub resolver does.

        Defaults to networkmanager.enable, which keeps it OFF for the static-IP hosts.
        It MUST stay off on optiplex-nas: Unbound binds 0.0.0.0:53, which would swallow
        resolved's 127.0.0.53 stub listener.
      '';
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
    networking.nameservers = lib.mkForce globalNameservers;

    networking.firewall.enable = cfg.firewall.enable;

    # === systemd-resolved (NetworkManager hosts) ===
    # NOTE: this nixpkgs still has the classic options (fallbackDns/llmnr/dnssec/
    # extraConfig). A future flake update migrates them to services.resolved.settings.Resolve.*
    services.resolved = lib.mkIf cfg.useResolved {
      enable = true;
      fallbackDns = cfg.fallbackDns;
      # Unbound does not sign the .lan zone; validation would only cause failures.
      dnssec = "false";
      # avahi owns local name discovery on these hosts (services.airplayReceiver and
      # friends enable it with nssmdns4). Leaving LLMNR/mDNS to resolved as well means
      # two daemons answering for the same names.
      llmnr = "false";
      extraConfig = ''
        MulticastDNS=no
      '';
    };

    # Encrypted DNS: dnscrypt-proxy on 127.0.0.1:53. Does not clash with resolved's
    # stub listener, which is on 127.0.0.53:53.
    # Skipped when localDns.server is set — the remote Unbound server handles upstream DoH instead.
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

    # With resolved, NetworkManager must hand link DNS *to* resolved — dns="none" would
    # cut it off and the per-domain scoping would never take effect. Without resolved,
    # keep resolv.conf under our control so NM can't overwrite it with DHCP servers.
    networking.networkmanager.dns =
      if cfg.useResolved then lib.mkForce "systemd-resolved"
      else lib.mkIf (cfg.encryptedDns.enable || cfg.localDns.server != null) (lib.mkForce "none");

    # glibc's stub resolver has no failure memory: with a dead first nameserver it pays
    # the full timeout on every lookup before trying the next. Default is timeout:5
    # attempts:2 — up to 10s per name. Only relevant off the resolved path.
    networking.resolvconf.extraOptions = lib.mkIf (!cfg.useResolved) [ "timeout:1" "attempts:1" ];
  };
}
