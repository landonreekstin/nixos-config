# ~/nixos-config/hosts/asus-laptop/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";

      programs.chat = { package = pkgs.discord; exe = "discord"; };
      # nixpkgs removed brave (2026-W46), so the alt browser is the Flathub build.
      programs.browserAlt = {
        package = null;
        command = "flatpak run com.brave.Browser";
      };
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
        "claude-code"
      ];
      # vscode, librewolf, brave (flatpak) and signal-desktop come from
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
          "com.brave.Browser"
        ];
      };
    };

  };

  # In your NixOS configuration
  services.flatpak.enable = true;
}
