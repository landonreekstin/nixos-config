# ~/nixos-config/hosts/vm-sandbox/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
    };

    packages = {
      nixos = with pkgs; [ ];
      unstable-override = [ ];
      homeManager = with pkgs; [
        kitty
        notes
        vesktop  # screen-share / ScreenCast portal testing in a real Plasma Wayland session
      ];
      flatpak.enable = false;
    };

  };
}
