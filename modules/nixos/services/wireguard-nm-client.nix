# ~/nixos-config/modules/nixos/services/wireguard-nm-client.nix
{ config, lib, ... }:

with lib;

let
  cfg = config.customConfig.services.wireguard.nmClient;
in
{
  # NetworkManager-based WireGuard client (KDE/GNOME applet-toggleable), distinct from
  # customConfig.services.wireguard.client (wireguard-client.nix), which is a systemd/
  # wg-quick interface. Use this for hosts where the user should turn the VPN on/off
  # from the desktop network UI.
  options.customConfig.services.wireguard.nmClient = with lib; {
    enable = mkEnableOption "declarative NetworkManager WireGuard client profile (appears in the KDE/GNOME network applet, user-toggleable)";
    connectionName = mkOption {
      type = types.str;
      default = "homelab-vpn";
      description = "NetworkManager connection id (shown in the network applet).";
    };
    interfaceName = mkOption {
      type = types.str;
      default = "wg-homelab";
      description = "WireGuard interface name for the NM connection.";
    };
    autoconnect = mkOption {
      type = types.bool;
      default = false;
      description = "Auto-connect the tunnel on login. false = user toggles it in the applet.";
    };
    address = mkOption {
      type = types.str;
      example = "10.10.0.5/32";
      description = "This client's tunnel address (CIDR).";
    };
    dns = mkOption {
      type = types.str;
      default = "";
      example = "192.168.1.76";
      description = "DNS server to use while the tunnel is up (empty = leave NM default).";
    };
    privateKeySopsSecret = mkOption {
      type = types.str;
      default = "wg-nm-private-key";
      description = "Name of the sops secret holding this client's WireGuard private key.";
    };
    sopsFile = mkOption {
      type = types.path;
      description = "The sops file that contains the private-key secret for this host.";
    };
    peer = {
      publicKey = mkOption {
        type = types.str;
        description = "The WireGuard server's public key.";
      };
      endpoint = mkOption {
        type = types.str;
        example = "68.184.198.204:51822";
        description = "Server endpoint as host:port.";
      };
      allowedIPs = mkOption {
        type = types.str;
        example = "192.168.1.76/32;";
        description = ''NM keyfile-format allowed-ips (semicolon-separated, e.g. "192.168.1.76/32;").'';
      };
      persistentKeepalive = mkOption {
        type = types.int;
        default = 25;
        description = "Keepalive interval in seconds.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Client private key comes from sops (never in the Nix store). sops-nix renders it
    # into an env file that NetworkManager's ensureProfiles substitutes at activation,
    # so the key stays out of both the store and the plaintext NM keyfile on disk.
    sops.secrets.${cfg.privateKeySopsSecret}.sopsFile = cfg.sopsFile;

    sops.templates."${cfg.connectionName}-wg.env".content =
      "WG_PRIVATE_KEY=${config.sops.placeholder.${cfg.privateKeySopsSecret}}";

    # Declarative NetworkManager WireGuard connection. Because it's an NM profile, it
    # shows up in the KDE Plasma / GNOME network applet and can be toggled on/off by the
    # user — no manual import, no key on disk in cleartext.
    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.templates."${cfg.connectionName}-wg.env".path ];
      profiles.${cfg.connectionName} = {
        connection = {
          id = cfg.connectionName;
          type = "wireguard";
          interface-name = cfg.interfaceName;
          autoconnect = cfg.autoconnect;
        };
        wireguard = {
          private-key = "$WG_PRIVATE_KEY";
        };
        "wireguard-peer.${cfg.peer.publicKey}" = {
          endpoint = cfg.peer.endpoint;
          allowed-ips = cfg.peer.allowedIPs;
          persistent-keepalive = cfg.peer.persistentKeepalive;
        };
        ipv4 = {
          method = "manual";
          address1 = cfg.address;
        } // optionalAttrs (cfg.dns != "") {
          dns = "${cfg.dns};";
          ignore-auto-dns = true;
        };
        ipv6.method = "disabled";
      };
    };
  };
}
