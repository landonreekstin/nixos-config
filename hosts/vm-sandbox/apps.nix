# ~/nixos-config/hosts/vm-sandbox/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";

      programs.chat = { package = pkgs.discord; exe = "discord"; };
    };

    packages = {
      nixos = with pkgs; [ ];
      # librewolf was pulled from unstable here because 25.11's 152.0.2-1 was
      # marked insecure and never built by Hydra. 26.05's 156.0-1 is cached, so
      # the test VM matches the real hosts on stable again.
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
