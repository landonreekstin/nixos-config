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