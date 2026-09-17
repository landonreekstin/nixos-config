# ~/nixos-config/hosts/mini-server/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    packages = {
      nixos = with pkgs; [ wget git vim htop claude-code restic ];
      unstable-override = [ "claude-code" ];
      homeManager = [];
    };

    programs.claudeCode = {
      enable = true;
      remoteControl = {
        atStartup = true;
        server.enable = true;
      };
    };

  };
}
