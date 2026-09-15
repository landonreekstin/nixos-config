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
      # librewolf: home.nix enables it as a browser-config surface, and stable 25.11's
      # 152.0.2-1 is marked insecure so Hydra never built it. Match the real hosts and
      # take unstable's cached build instead of compiling a Firefox fork in a test VM.
      unstable-override = [ "librewolf" ];
      homeManager = with pkgs; [
        kitty
        notes
        vesktop  # screen-share / ScreenCast portal testing in a real Plasma Wayland session
      ];
      flatpak.enable = false;
    };

  };
}
