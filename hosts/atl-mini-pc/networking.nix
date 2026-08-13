# ~/nixos-config/hosts/atl-mini-pc/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = true;
    vscodeServer.enable = true;
    wireguard.server = {
      enable = false;
      address = "10.100.100.1/24";
      listenPort = 51824;
      privateKeyFile = "/etc/nixos/secrets/wireguard/server-privatekey"; # IMPORTANT: Use a secret path
      peers = [
        {
          # Example Peer 1: A Phone
          publicKey = "PKvb7VKgYKXobS0MjVg68NbkObZVO9Bdakjv7Hi5NGw=";
          allowedIPs = [ "10.200.200.2/32" ];
        }
      ];
    };
  };
}
