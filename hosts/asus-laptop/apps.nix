# ~/nixos-config/hosts/asus-laptop/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
    };

    programs = {
      partydeck.enable = false;
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [
        kitty
      ];
      unstable-override = [
        "vscode"
        "librewolf"
        "brave"
        "claude-code"
      ];
      # vscode, librewolf, brave and signal-desktop come from
      # customConfig.apps.programs (ide, browser, browserAlt, chatAlt).
      homeManager = with pkgs; [
        jamesdsp
        remmina
        vesktop
        claude-code
        (callPackage ../../pkgs/worldmonitor { })
        (callPackage ../../pkgs/spotatui { })
        (callPackage ../../pkgs/tuisic { })
        mapscii
        astroterm
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
        ];
      };
    };

  };

  # In your NixOS configuration
  services.flatpak.enable = true;
}
