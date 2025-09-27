# ~/nixos-config/modules/nixos/services/wireguard-client.nix
{ config, lib, pkgs, ... }:

with lib;

let
  # Create a reference to our custom client options for convenience
  cfg = config.customConfig.services.wireguard.client;
in
{
  # This makes the module's configuration conditional on our custom option
  config = mkIf cfg.enable {

    # This is the main switch to turn on WireGuard support in the kernel and with tools.
    networking.wireguard.enable = true;

    # Configure the specific WireGuard interface using our custom options.
    networking.wireguard.interfaces = {
      # Hardcoded interface name for simplicity
      "wg0" = {
        # The client's own IP address within the WireGuard network.
        ips = [ cfg.address ];

        # The path to the client's secret private key.
        privateKeyFile = cfg.privateKeyFile;

        # --- DNS Configuration ---
        # This prevents your home DNS from leaking when the VPN is active.
        # It sets a public DNS server for the tunnel and reverts when disconnected.
        postSetup = ''
          ${pkgs.systemd}/bin/resolvectl dns %i 1.1.1.1
        '';
        postShutdown = ''
          ${pkgs.systemd}/bin/resolvectl revert %i
        '';

        # Define the server (peer) that this client will connect to.
        peers = [
          {
            publicKey = cfg.peer.publicKey;
            endpoint = cfg.peer.endpoint;

            # Hardcoded: Route all traffic through the VPN.
            allowedIPs = [ "0.0.0.0/0" "::/0" ];

            # Hardcoded: Standard keepalive to maintain connection through NAT.
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}