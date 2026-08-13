# ~/nixos-config/hosts/optiplex-nas/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    programs = {
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [
        wget
        git
        vim
        htop
        claude-code
      ];
      homeManager = with pkgs; [
        vscode
      ];
    };

  };
}
