# ~/nixos-config/modules/nixos/services/wireguard-nm-client.nix
{ config, lib, ... }:

with lib;

let
  cfg = config.customConfig.services.wireguard.nmClient;
in
{
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
