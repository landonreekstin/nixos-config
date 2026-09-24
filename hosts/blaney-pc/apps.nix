# ~/nixos-config/hosts/blaney-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    apps = {
      defaultSet = "kde";
      defaults.kde.browser = "org.chromium.Chromium.desktop";

      programs = {
        # Chromium comes from Flatpak here, so no native browser is installed.
        # Super+B still works and matches the NAV launcher entry.
        browser = {
          package = null;
          command = "flatpak run org.chromium.Chromium";
        };
        # Discord also comes from Flatpak; vesktop is the native client used.
        chat = { package = pkgs.vesktop; exe = "vesktop"; };
      };
    };

    programs = {
      # Off since KDE was dropped from this host. partydeck is not built against KWin,
      # but its `enable_kwin_script` setting defaults to on and its launch path calls
      # KWin over D-Bus with `?` — so without Plasma a launch aborts, and unticking the
      # setting leaves you hand-positioning every split-screen window. Nobody was using
      # it, so it is off rather than half-working. See modules/nixos/programs/partydeck.nix.
      partydeck.enable = false;
      claudeCode.enable = true;
    };

    packages = {
      nixos = with pkgs; [
      ];
      unstable-override = [
        "obs-studio"
        "vscode"
        # "firefox" was overridden here because 25.11's pin (152.0.4) had fallen
        # out of the cache and source-rebuilt until the flake-updater timed out
        # on W39. 26.05 ships a cached 156.0, so stable is fine again.
        #"librewolf"
        #"brave"
        #"chromium"
        "desmume"
        "mgba"
        "claude-code"
        "signal-desktop"
      ];
      # kitty, vscode, vesktop and signal-desktop come from
      # customConfig.apps.programs (terminal, ide, chat, chatAlt).
      homeManager = with pkgs; [
        obs-studio
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
        desmume
        mgba
        claude-code
        wireguard-ui
        (callPackage ../../pkgs/worldmonitor { })
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
          "org.chromium.Chromium"
        ];
      };
    };

  };
}
