# ~/nixos-config/modules/nixos/services/wireguard-client.nix
{ config, lib, ... }:

with lib;

let
  cfg = config.customConfig.services.wireguard.client;
in
{
  options.customConfig.services.wireguard.client = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the WireGuard client configuration.";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically start the WireGuard client on boot.";
    };

    interfaceName = mkOption {
      type = types.str;
      default = "wg0";
      description = "The name of the WireGuard network interface.";
    };

    address = mkOption {
      type = types.str;
      example = "10.10.0.3/32";
      description = "The IP address for this client within the tunnel.";
    };

    dns = mkOption {
      type = with types; listOf str;
      default = [];
      description = "DNS servers to use when the tunnel is active.";
    };

    privateKeyFile = mkOption {
      type = types.path;
      description = "Absolute path to the file containing the client's private key.";
    };

    peer = {
      publicKey = mkOption {
        type = types.str;
        description = "The public key of the WireGuard server.";
      };
      allowedIPs = mkOption {
        type = with types; listOf str;
        default = [ "0.0.0.0/0" ];
        description = "IP ranges to route through the tunnel.";
      };
      endpoint = mkOption {
        type = types.str;
        description = "The server endpoint as host:port.";
      };
      persistentKeepalive = mkOption {
        type = types.int;
        default = 25;
        description = "Keepalive interval in seconds (0 to disable).";
      };
    };
  };

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

    systemd.services."wg-quick-${cfg.interfaceName}" = mkIf (!cfg.autoStart) {
      wantedBy = mkForce [];
    };
  };
}
