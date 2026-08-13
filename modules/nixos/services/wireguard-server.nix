# ~/nixos-config/modules/nixos/services/wireguard-server.nix
{ config, lib, pkgs, ... }:

with lib;

let
  # Create a reference to our custom options for convenience
  cfg = config.customConfig.services.wireguard.server;
in
{
  options.customConfig.services.wireguard.server = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the WireGuard server host configuration.";
    };
    
    interfaceName = mkOption {
      type = types.str;
      default = "wg0";
      description = "The name of the WireGuard network interface.";
    };

    address = mkOption {
      type = types.str;
      example = "10.100.100.1/24";
      description = "The IP address and subnet for the WireGuard server itself.";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "The UDP port on which the WireGuard server will listen.";
    };

    privateKeyFile = mkOption {
      type = types.path;
      description = "Absolute path to the file containing the server's private key.";
      example = "/etc/nixos/secrets/wireguard/private";
    };

    peers = mkOption {
      type = with types; listOf (submodule {
        options = {
          publicKey = mkOption {
            type = types.str;
            description = "The public key of the peer.";
          };
          allowedIPs = mkOption {
            type = with types; listOf str;
            description = "List of IP addresses this peer is allowed to use within the tunnel.";
            example = [ "10.100.100.2/32" ];
          };
          presharedKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Optional: Absolute path to a pre-shared key for this peer for extra security.";
          };
        };
      });
      default = [];
      description = "A list of peers (clients) that are allowed to connect to this server.";
    };
  };

  # This makes the module's configuration conditional on our custom option
  config = mkIf cfg.enable {

    # This is the main switch to turn on WireGuard support in the kernel and with tools.
    networking.wireguard.enable = true;

    # --- NEW: Enable IP forwarding to allow the server to act as a router ---
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1; # Also enable for IPv6
    };

    # Configure the specific WireGuard interface using our custom options.
    networking.wireguard.interfaces = {
      ${cfg.interfaceName} = {
        ips = [ cfg.address ];
        listenPort = cfg.listenPort;
        privateKeyFile = cfg.privateKeyFile;
        peers = map (peer: {
          publicKey = peer.publicKey;
          allowedIPs = peer.allowedIPs;
          presharedKeyFile = peer.presharedKeyFile;
        }) cfg.peers;
      };
    };

    networking.firewall = {
      # Automatically open the firewall for the WireGuard listening port.
      allowedUDPPorts = [ cfg.listenPort ];
      
      # Enable NAT/Masquerading for the WireGuard interface.
      # This allows clients to access the internet through the server.
      # We mark the WireGuard interface as "trusted" which tells the firewall
      # to handle the masquerading for us automatically.
      trustedInterfaces = [ cfg.interfaceName ];
    };

  };
}
