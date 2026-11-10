# ~/nixos-config/hosts/justus-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps.defaultSet = "kde";

    programs = {
      partydeck.enable = false;
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [
        "vscode"
        "ungoogled-chromium"
      ];
      homeManager = with pkgs; [
        vscode
        librewolf
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
          "com.brave.Browser"  # nixpkgs removed brave (2026-W46)
        ];
      };
    };

  };
}
