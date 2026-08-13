# ~/nixos-config/hosts/gaming-pc/networking.nix
{ config, pkgs, lib, ... }:

let
  vars = import ./vars.nix;
in
{
  customConfig = {

    networking = {
      wakeOnLan = {
        enable = true;
        interface = "enp8s0";
      };
      encryptedDns = {
        enable = true;
        resolver = "cloudflare";
      };
      localDns.server = "192.168.1.76";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;

      # Dedicated LAN WireGuard peer for private NAS access (post-migration).
      # Gated by the nasViaLanWg flag in vars.nix. When enabled, captures only
      # 192.168.100.76 traffic through the tunnel — the rest of the network stays
      # direct. Endpoint is the fw's LAN IP, so no internet trip is involved when
      # gaming-pc is on the home LAN.
      wireguard.client = lib.mkIf vars.nasViaLanWg {
        enable = true;
        interfaceName = "wg-nas";
        address = "10.10.0.11/32";
        privateKeyFile = config.sops.secrets.wg-nas-private-key.path;
        peer = {
          publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
          allowedIPs = [ "192.168.100.76/32" ];
          endpoint = "192.168.1.189:51822";
          persistentKeepalive = 25;
        };
      };
    };

  };

  # sops secret for the wg-nas private key. Only declared when nasViaLanWg is on
  # so eval doesn't require the key to be present in gaming-pc.yaml pre-migration.
  sops.secrets = lib.mkIf vars.nasViaLanWg {
    wg-nas-private-key.sopsFile = ../../secrets/gaming-pc.yaml;
  };

  # Enable the Samba client-side name resolution daemon (nmbd).
  # This allows the PC to discover other Samba hosts (like optiplex-nas)
  # on the local network by their hostname.
  services.samba.nmbd.enable = true;
  networking.firewall.allowedTCPPorts = [ 139 445 4445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  networking.extraHosts = ''
    192.168.1.76  optiplex-nas
    192.168.1.76  reader.lan jellyfin.lan jellyseerr.lan transmission.lan radarr.lan sonarr.lan bazarr.lan prowlarr.lan nix-cache.lan
  '';

  # Enable TCP MTU probing / blackhole detection.
  # WireGuard tunnel MTU (~1420) is smaller than standard Ethernet (1500). If a packet
  # is too large to traverse the tunnel, the intermediate router sends back ICMP
  # "fragmentation needed". With probing enabled, the kernel detects when these are
  # dropped (blackhole) and adaptively reduces MSS, preventing SSH/TCP stalls.
  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1;

  # Routes through OpenBSD firewall for accessing server subnet and public IP hairpin NAT
  # Uses NetworkManager dispatcher to add routes when enp8s0 comes up
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "homelab-routes" ''
        #!/bin/sh
        if [ "$1" = "enp8s0" ] && [ "$2" = "up" ]; then
          # Route to server subnet (192.168.100.x) via OpenBSD firewall
          ${pkgs.iproute2}/bin/ip route add 192.168.100.0/24 via 192.168.1.189 dev enp8s0 || true
          # Route for Astroneer public IP hairpin NAT
          ${pkgs.iproute2}/bin/ip route add 68.184.198.204/32 via 192.168.1.189 dev enp8s0 || true
        fi
      '';
      type = "basic";
    }
  ];
}
