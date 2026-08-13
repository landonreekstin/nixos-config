# ~/nixos-config/hosts/asus-m15/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = true;
    vscodeServer.enable = true;
  };
}
