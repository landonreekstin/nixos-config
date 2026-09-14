# ~/nixos-config/modules/nixos/common/lan-hosts.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.networking.lanHosts;
  records = import ./lan-records.nix;

  nasLine = "${cfg.nasAddress}  ${lib.concatMapStringsSep " " (n: "${n}.lan") records.nasNames}";
  fixedLines = map (r: "${r.addr}  ${r.name}") records.fixedRecords;
in
{
  options.customConfig.networking.lanHosts = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Write the .lan zone into networking.extraHosts (i.e. /etc/hosts) on this host.

        This is deliberate redundancy with the Unbound server on optiplex-nas: when the
        NAS is down its own DNS is down with it, and without these entries every .lan
        name stops resolving on every client. /etc/hosts is consulted before DNS, so
        .lan keeps working regardless of the NAS's state.

        Opt-in, because these are private addresses that are only correct on the home
        LAN (or behind it). A remote host — blaney-pc reaches the homelab only through
        the VPN — would get 192.168.1.76 pointing at whatever happens to sit at that
        address on ITS network, which is worse than having no .lan entry at all.
      '';
    };
    nasAddress = mkOption {
      type = types.str;
      default = "192.168.1.76";
      description = ''
        Address at which this host reaches optiplex-nas for the NAS-served .lan names.
        Default is the legacy Main-LAN IP (a firewall alias post-migration, rdr'd to
        192.168.100.76). Hosts behind the firewall on the server subnet must override
        to 192.168.100.76 — the legacy alias is not reachable from there.
      '';
      example = "192.168.100.76";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.extraHosts = lib.concatStringsSep "\n" (
      [ "${cfg.nasAddress}  optiplex-nas" nasLine ] ++ fixedLines
    );
  };
}
