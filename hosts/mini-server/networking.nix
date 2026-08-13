# ~/nixos-config/hosts/mini-server/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    networking = {
      networkmanager.enable = false;
      staticIP = {
        enable = true;
        interface = "enp1s0";
        address = "192.168.100.103";
        gateway = "192.168.100.1";
      };
      firewall.enable = false;
      # NAS (Unbound resolver) lives on this same server subnet post-migration;
      # reach it directly rather than via the firewall's legacy 192.168.1.76 alias.
      localDns.server = "192.168.100.76";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      autoUpdate.enable = true;
    };

  };
}
