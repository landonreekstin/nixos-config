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
        # "librewolf" was here because 25.11 marked 152.0.2-1 insecure, so Hydra
        # never built it and leaving it on stable compiled a whole Firefox fork
        # from source (that is what OOM-killed the weekly flake-updater on the
        # NAS). 26.05 ships a cached 156.0-1, so stable is fine again.
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
        # signal-desktop 8.25.0 from stable 25.11 pulls its own electron-unwrapped-
        # 43.4.1 variant that isn't cached (25.11 is EOL); source-building it on
        # the NAS TIMEOUT'd the weekly flake-updater on W39. Unstable's 8.26.0 is
        # cached with all its transitive deps. Every other host that carries this
        # role already overrides signal-desktop to unstable — this brings asus-m15
        # in line.
        "signal-desktop"
        "claude-code"
        "mullvad-vpn"
      ];
      # vscode comes from customConfig.apps.programs.ide.
      homeManager = with pkgs; [
        chromium
        firefox
        claude-code
        gopher64
        mullvad-vpn
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
