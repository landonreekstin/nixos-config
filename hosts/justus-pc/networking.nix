# ~/nixos-config/hosts/justus-pc/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;
  };
}
