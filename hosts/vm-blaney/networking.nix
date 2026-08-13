# ~/nixos-config/hosts/vm-blaney/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;
  };
}
