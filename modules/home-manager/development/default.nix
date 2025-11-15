# ~/nixos-config/modules/home-manager/development/default.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./embedded-linux.nix
    ./fpga-ice40.nix
  ];
}