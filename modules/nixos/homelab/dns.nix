# ~/nixos-config/modules/nixos/homelab/dns.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.dns;

  # Same map the clients' /etc/hosts is generated from, so the two can't drift.
  # See modules/nixos/common/lan-records.nix.
  records = import ../common/lan-records.nix;

  # Unbound serves clients on BOTH subnets from a single zone, so it keeps handing
  # out the legacy 192.168.1.76 alias for the NAS names. That is right for Main-LAN
  # clients and wrong for server-subnet / wg ones — splitting it needs
  # access-control-view clauses and is tracked as a follow-up. In the meantime those
  # clients get the correct address from their own lanHosts.nasAddress (/etc/hosts),
  # which is consulted before DNS.
  nasAddress = "192.168.1.76";

  mkLocalData = name: addr: ''"${name}. A ${addr}"'';
in
{
  options.customConfig.homelab.dns = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Unbound DNS server with a local .lan zone for homelab service names. Intended for optiplex-nas only.";
    };
  };

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
          local-data =
            # optiplex-nas
            (map (n: mkLocalData "${n}.lan" nasAddress) records.nasNames)
            # mini-server and anything else with a subnet-independent address
            ++ (map (r: mkLocalData r.name r.addr) records.fixedRecords);
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

    # optiplex-nas resolves through its own Unbound instance. Declared as the localDns
    # server rather than by writing networking.nameservers directly, so that the common
    # networking module stays the single place that composes the resolver list — it
    # appends fallbackDns, which keeps the NAS (and the flake-updater that runs on it)
    # resolving even when Unbound is stopped or crashed. 127.0.0.1 refuses instantly in
    # that case, so the extra entries cost nothing while Unbound is healthy.
    # (Two modules both mkForce-ing networking.nameservers would *concatenate*, not
    # override — that produced a duplicated list with a stray gateway entry.)
    customConfig.networking.localDns.server = "127.0.0.1";

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
