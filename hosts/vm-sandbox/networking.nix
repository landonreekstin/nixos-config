# ~/nixos-config/hosts/vm-sandbox/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;
  };
}
