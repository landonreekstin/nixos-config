# ~/nixos-config/modules/nixos/services/wireguard-client.nix
{ config, lib, ... }:

with lib;

let
  cfg = config.customConfig.services.wireguard.client;
in
{
  config = mkIf cfg.enable {
    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      address = [ cfg.address ];
      dns = cfg.dns;
      privateKeyFile = cfg.privateKeyFile;
      peers = [
        {
          publicKey = cfg.peer.publicKey;
          allowedIPs = cfg.peer.allowedIPs;
          endpoint = cfg.peer.endpoint;
          persistentKeepalive = cfg.peer.persistentKeepalive;
        }
      ];
    };
  };
}
