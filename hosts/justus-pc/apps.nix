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
        "librewolf"
        "brave"
        "ungoogled-chromium"
      ];
      homeManager = with pkgs; [
        vscode
        librewolf
        brave
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
        ];
      };
    };

  };
}
