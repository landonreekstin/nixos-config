# ~/nixos-config/hosts/optiplex/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    networking.wakeOnLan = {
      enable = true;
      interface = "eno2";
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };
}
