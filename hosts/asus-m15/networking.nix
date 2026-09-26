# ~/nixos-config/hosts/asus-m15/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = true;
    vscodeServer.enable = true;
    # WireGuard VPN — uncomment after in-person setup:
    #   1. wg genkey | tee /tmp/wg-private.key | wg pubkey  (note the public key)
    #   2. Add the public key to the WireGuard server as a new peer with IP 10.10.0.4/32
    #   3. ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub  (get this host's age key)
    #   4. Replace age1PLACEHOLDER_asus-m15 in .sops.yaml with the real age key
    #   5. sudo sops secrets/asus-m15.yaml  (create the file, add wireguard-private-key)
    #   6. Uncomment the block below and rebuild.
    #
    # wireguard.client = {
    #   enable = true;
    #   address = "10.10.0.4/32"; # verify this IP is free on the server
    #   dns = [ "1.1.1.1" ];
    #   privateKeyFile = config.sops.secrets.wireguard-private-key.path;
    #   peer = {
    #     publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
    #     allowedIPs = [ "0.0.0.0/0" ];
    #     endpoint = "68.184.198.204:51822";
    #     persistentKeepalive = 25;
    #   };
    # };
  };

  services.mullvad-vpn.enable = true;

  # Resolve optiplex-nas by hostname (used by the Jellyfin desktop client).
  # 192.168.1.76 is the firewall's legacy alias, rdr'd to the NAS at 192.168.100.76.
  # When WireGuard is enabled above this routes through the VPN tunnel.
  networking.hosts."192.168.1.76" = [ "optiplex-nas" ];
  # Uncomment after setting up the sops secret (step 5 above):
  # sops.secrets.wireguard-private-key = {};
}
