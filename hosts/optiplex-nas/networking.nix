# ~/nixos-config/hosts/optiplex-nas/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    networking = {
      networkmanager = {
        enable = false; # Disable NetworkManager for static IP
      };
      staticIP = {
        enable = true;
        interface = "enp0s31f6";
        address = "192.168.100.76";
        gateway = "192.168.100.1";
      };
      # Wake-on-LAN: the NAS had NO remote recovery path when it went down — no WoL, no
      # IPMI, and the firewall ages its MAC out of ARP, so reviving it needed physical
      # access. ethtool sets `wol g` on boot; the BIOS must also have WoL enabled for
      # this to work. Wake with `wol -h 192.168.100.255 <mac>` from optiplex-fw.
      wakeOnLan = {
        enable = true;
        interface = "enp0s31f6";
      };
      firewall = { enable = false; };
      # The NAS is the .lan server; its own /etc/hosts must use its real address, not
      # the firewall alias it sits behind.
      lanHosts.nasAddress = "192.168.100.76";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      autoUpdate = {
        enable = true;
        day = "Tue";
      };
    };

  };

  # === Return routes for legacy-LAN and WireGuard subnets (post-fw migration) ===
  # The NAS runs Mullvad as a full-tunnel VPN (see homelab.mullvad), whose policy
  # routing (`ip rule ... suppress_prefixlength 0` + a fwmark default) pushes any
  # destination NOT present in the main routing table into the tunnel. Now that the
  # NAS lives on 192.168.100.0/24 behind optiplex-fw, replies to main-LAN clients
  # (192.168.1.0/24, which reach NAS services via the firewall's legacy 192.168.1.76
  # alias) and to WireGuard peers (10.10.0.0/24) would otherwise disappear into
  # Mullvad. These explicit main-table routes send that return traffic back through
  # the firewall. Without them, DNS/Jellyfin/Samba break for everything that isn't
  # on the NAS's own server subnet. (`mullvad lan set allow` already permits these
  # private ranges through Mullvad's firewall; only the routes were missing.)
  networking.interfaces.enp0s31f6.ipv4.routes = [
    { address = "192.168.1.0"; prefixLength = 24; via = "192.168.100.1"; }
    { address = "10.10.0.0";   prefixLength = 24; via = "192.168.100.1"; }
  ];
}
