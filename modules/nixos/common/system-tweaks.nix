# ~/nixos-config/modules/nixos/common/system-tweaks.nix
{ config, pkgs, lib, ... }:
{
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';
  services.logind.extraConfig = ''
    IdleAction=ignore
    IdleActionSec=0
  '';
}