# ~/nixos-config/hosts/optiplex/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    # ungoogled-chromium, not plain chromium: this host already installed
    # ungoogled-chromium (and overrides it to unstable below), and both packages
    # ship bin/chromium, so having the role on one and the package list on the
    # other made home-manager's buildEnv fail with a conflicting subpath — the
    # host could not build at all. ungoogled-chromium provides the same
    # bin/chromium and chromium-browser.desktop that the pinned taskbar entry in
    # home.nix refers to, so the role points at it and the duplicate entry in
    # packages.homeManager is gone.
    #
    # This predates the 26.05 upgrade; CI only evaluates optiplex, never builds
    # it, so the collision was never surfaced.
    apps.programs.browserAlt = { package = pkgs.ungoogled-chromium; exe = "chromium"; };
    apps.programs.chat = { package = pkgs.discord; exe = "discord"; };

    programs = {
      partydeck.enable = false;
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [
        firefox
        kitty
        claude-code
      ];
      unstable-override = [
        "vscode"
        "ungoogled-chromium"
        "claude-code"
      ];
      # vscode comes from customConfig.apps.programs.ide.
      # ungoogled-chromium is installed by the browserAlt role above — listing it
      # here as well is what caused the buildEnv collision.
      homeManager = with pkgs; [
        jamesdsp
        remmina
        notes
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
