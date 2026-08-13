# ~/nixos-config/hosts/mini-server/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    packages = {
      nixos = with pkgs; [ wget git vim htop claude-code restic ];
      homeManager = [];
    };

    programs.claudeCode.enable = true;

  };
}
