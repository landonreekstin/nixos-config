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
      # Same reason: the legacy 192.168.1.76 alias is not reachable from behind the fw.
      lanHosts.enable = true;
      lanHosts.nasAddress = "192.168.100.76";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      # TEMPORARILY DISABLED for the nixos-26.05 upgrade — see the same note on
      # optiplex-nas. mini-server is the most recoverable of the three (reachable
      # through optiplex-fw), but it should still be the deliberate first host we
      # reboot onto 26.05 rather than finding out by surprise.
      # TODO: set back to true once mini-server is verified on 26.05.
      autoUpdate.enable = false;
    };

  };
}
