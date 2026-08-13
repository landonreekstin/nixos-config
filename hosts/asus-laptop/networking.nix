# ~/nixos-config/hosts/asus-laptop/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = true;
    vscodeServer.enable = true;
    wireguard.client = {
      enable = true;
      autoStart = false;
      address = "10.10.0.3/32";
      dns = [ "192.168.1.76" "1.1.1.1" ];
      privateKeyFile = config.sops.secrets.wireguard-private-key.path;
      peer = {
        publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "68.184.198.204:51822";
        persistentKeepalive = 25;
      };
    };
  };

  sops.secrets.wireguard-private-key = {};

  # gaming-pc is on the home LAN (192.168.1.0/24), which conflicts with many
  # external networks. Add a /32 host route via the WireGuard interface so
  # the more-specific route wins over the local subnet route.
  networking.wg-quick.interfaces.wg0.postUp = [
    "ip route add 192.168.1.60/32 dev wg0"
    "ip route add 192.168.1.76/32 dev wg0"
  ];
  networking.wg-quick.interfaces.wg0.preDown = [
    "ip route del 192.168.1.60/32 dev wg0 || true"
    "ip route del 192.168.1.76/32 dev wg0 || true"
  ];

  networking.hosts."192.168.1.60" = [ "gaming-pc" ];
  networking.hosts."192.168.1.76" = [ "optiplex-nas" ];
}
