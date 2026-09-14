# ~/nixos-config/hosts/optiplex/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    networking = {
      wakeOnLan = {
        enable = true;
        interface = "eno2";
      };
      # Home LAN, so the .lan addresses are correct here. useResolved is deliberately
      # left off: this host sets no localDns.server, so resolved would buy it only a
      # FallbackDNS tier it doesn't need, and it hasn't been rebuilt to verify.
      lanHosts.enable = true;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };
}
