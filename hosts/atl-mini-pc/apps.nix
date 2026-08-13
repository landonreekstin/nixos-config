# ~/nixos-config/hosts/atl-mini-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "firefox.desktop";
    };

    programs = {
      partydeck.enable = false;
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [
        "firefox"
        "chromium"
      ];
      homeManager = with pkgs; [
        notes
        chromium
        firefox
        libreoffice
      ];
      flatpak.enable = true;
    };

  };
}
