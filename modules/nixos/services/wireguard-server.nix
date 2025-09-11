# ~/nixos-config/modules/nixos/services/wireguard-server.nix
{ config, lib, pkgs, ... }:

with lib;

let
  # Create a reference to our custom options for convenience
  cfg = config.customConfig.services.wireguard.server;
in
{
  # This makes the module's configuration conditional on our custom option
  config = mkIf cfg.enable {
        # This is the main switch to turn on WireGuard support in the kernel and with tools.
        networking.wireguard.enable = true;

        # Configure the specific WireGuard interface using our custom options.
        networking.wireguard.interfaces = {
            # The attribute name here is the interface name, e.g., "wg0".
            ${cfg.interfaceName} = {
                # The server's own IP address within the WireGuard network.
                ips = [ cfg.address ];

                # The port the server listens on for connections from peers.
                listenPort = cfg.listenPort;

                # The path to the server's secret private key.
                privateKeyFile = cfg.privateKeyFile;

                # Define the clients (peers) that are allowed to connect.
                # We map over the list of peers defined in the customConfig.
                peers = map (peer: {
                publicKey = peer.publicKey;
                allowedIPs = peer.allowedIPs;
                presharedKeyFile = peer.presharedKeyFile; # Can be null
                }) cfg.peers;
            };
        };

        # Automatically open the firewall for the WireGuard listening port.
        networking.firewall.allowedUDPPorts = [ cfg.listenPort ];

    };
}