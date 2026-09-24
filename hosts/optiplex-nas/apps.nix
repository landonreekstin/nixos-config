# ~/nixos-config/hosts/optiplex-nas/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    programs = {
      claudeCode = {
        enable = true;
        remoteControl = {
          atStartup = true;
          server.enable = true;
        };
      };
    };

    packages = {
      nixos = with pkgs; [
        wget
        git
        vim
        htop
        claude-code
      ];
      unstable-override = [
        "claude-code"
      ];
      homeManager = with pkgs; [
        vscode
      ];
    };

  };
}
