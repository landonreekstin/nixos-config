# ~/nixos-config/hosts/asus-m15/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "chromium.desktop";

      programs.chat = { package = pkgs.discord; exe = "discord"; };
    };

    programs = {
      partydeck.enable = true;
      flatpak.enable = true;
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [
        "vscode"
        # "chromium" — do NOT re-add without checking the electron fallout.
        # unstable-overlay.nix replaces pkgs.<name> globally, and nixpkgs builds
        # electron out of chromium's infrastructure. Overriding chromium here
        # rebuilt stable signal-desktop's electron-unwrapped against unstable's
        # dep tree (glib 2.88 / rustc 1.97 / python 3.14 vs stable's 2.86 / 1.91
        # / 3.13), producing a hybrid derivation Hydra has never built — so it
        # compiled electron from source and TIMEOUTed the weekly flake-updater
        # build for asus-m15 (2026-W33). With chromium on stable, the electron
        # drv matches asus-laptop's cached one exactly.
        "firefox"
        "claude-code"
      ];
      # vscode comes from customConfig.apps.programs.ide.
      homeManager = with pkgs; [
        chromium
        firefox
        claude-code
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
