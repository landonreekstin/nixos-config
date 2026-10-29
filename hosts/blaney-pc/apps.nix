# ~/nixos-config/hosts/blaney-pc/apps.nix
{ config, pkgs, lib, ... }:

{
  # KDE System Monitor, kept when Plasma was dropped from this host. It only draws what
  # ksystemstats reports, and ksystemstats is D-Bus-activated (org.kde.ksystemstats1 →
  # plasma-ksystemstats.service), so it has to be registered with dbus and systemd, not
  # just installed — plasma6 used to do that. Without it the app opens with empty graphs.
  environment.systemPackages = [ pkgs.kdePackages.plasma-systemmonitor pkgs.kdePackages.ksystemstats ];
  services.dbus.packages = [ pkgs.kdePackages.ksystemstats ];
  systemd.packages = [ pkgs.kdePackages.ksystemstats ];

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
      # His R62D game (github.com/cblaney00/r62d) as an app; port 6262 open so friends can join his games.
      r62d = { enable = true; openFirewall = true; };
      # His own vibe-coded app projects: the `vibe` command, ~/projects, and the dev
      # shells its .envrc files point at (customConfig.profiles.development.vibe-* in
      # ./profiles.nix). See docs/hosts/blaney-vibe-projects.md.
      vibeProjects = {
        enable = true;
        # His packaged apps are built from his project folders here, so a rebuild always
        # installs his newest work. Their pins are only *releases* for Lando's machines and
        # are never bumped to get a change onto this one (docs/companion-repos.md).
        localApps = { glade = "glade"; r62d = "r62d"; };
      };
      # The Batman (JAKKS TV game) with Lando: "The Batman: Join Online Game" in the start
      # menu, with the homelab VPN on. modules/nixos/programs/batman.nix.
      batman.enable = true;
      # Steel Horizon RTS, Lando's naval battle game on the PSP game's assets: "Steel Horizon"
      # in the start menu. The first run downloads the ISO from the NAS drop (homelab VPN
      # on). modules/nixos/programs/steel-horizon.nix.
      steel-horizon.enable = true;
      # Sub of Seas, Lando's co-op submarine game: "Sub of Seas" in the start menu, then Join
      # (the address is filled in), with the homelab VPN on. Each start fetches Lando's
      # newest build from the NAS drop. modules/nixos/programs/sub-of-seas.nix.
      sub-of-seas.enable = true;
      # PC ports and recomps from the Quiver catalog, under Games in the start menu.
      # modules/nixos/programs/quiver.nix.
      quiver.enable = true;
      # Call of Duty: Modern Warfare 2 (2009) on community servers. The game itself is
      # not packaged -- the module ships `mw2-install` (builds MW2 from its install ISOs)
      # and `iw4x` (syncs the IW4x client, then launches it). installDir defaults to
      # ~/Games/mw2 and no mediaDir is set: this host fetches the media over HTTP from the
      # NAS public drop rather than from a mount, so the path is passed on the command line
      # (docs/runbooks/mw2-iw4x-source.md).
      #
      # gamescope.output{Width,Height} stay unset deliberately. They only matter above
      # 1080p, and this host tops out at 1920x1080 (DP-1 1920x1080 + HDMI-0 1600x900), so
      # gamescope using the native mode is already correct.
      iw4x.enable = true;
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
        kdePackages.kolourpaint
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
