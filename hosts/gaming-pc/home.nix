# ~/nixos-config/hosts/gaming-pc/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true;
    services.updateNotification.enable = true;
    themes = {
      hyprland = "century-series";
      xfce = "windows7";   # X11 desktop option; pick "Xfce Session" at the Ly greeter
      wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
      xfcePanel.trayApplets = [ "network" "bluetooth" "power" "clipboard" "nightlight" ];
      xfcePanel.nightlight = { tempDay = 6500; tempNight = 1500; };
      # gaming-pc's own pinned set (icon-only, left→right). Librewolf uses the Win7 Aero
      # "internet-web-browser" icon (the Internet Explorer blue-e in this theme). Spotify
      # forces X11 ozone since XFCE is an X11 session (its default .desktop has a Wayland
      # ozone flag that fails under X11).
      xfcePanel.pinnedApps = [
        { name = "Terminal";        exec = "kitty";                  icon = "kitty"; }
        { name = "System Settings"; exec = "xfce4-settings-manager"; icon = "preferences-system"; }
        { name = "Files";           exec = "thunar";                 icon = "system-file-manager"; }
        { name = "Librewolf";       exec = "librewolf";              icon = "internet-web-browser"; }
        { name = "Firefox";         exec = "firefox";                icon = "firefox"; }
        { name = "Chromium";        exec = "chromium";               icon = "chromium"; }
        { name = "Heroic";          exec = "heroic";                 icon = "com.heroicgameslauncher.hgl"; }
        { name = "Steam";           exec = "steam";                  icon = "steam"; }
        # Flatpak app id as the icon name — the flatpak exports its icon under that
        # name, not "discord" (same as blaney-pc's pins).
        { name = "Discord";         exec = config.customConfig.apps.programs.chat.command; icon = "com.discordapp.Discord"; }
        { name = "Signal";          exec = "signal-desktop";         icon = "signal-desktop"; }
        { name = "Spotify";         exec = "env NIXOS_OZONE_WL=0 spotify"; icon = "spotify-client"; }
        { name = "VS Code";         exec = "code";                   icon = "vscode"; }
      ];
    };

    # Firefox is the primary browser here (Super+B, and the default for
    # text/html and every xdg-open). It replaced LibreWolf on 2026-09-15 after
    # the docs/browsers.md checklist passed on this machine — chrome theme,
    # Widevine/Prime playback, .lan, saved logins surviving a restart, search
    # keywords, and the sops-backed bookmarks.
    #
    # LibreWolf stays installed as a fallback (apps.nix) but is NOT managed by
    # this module: nothing here touches ~/.librewolf, so its hand-configured
    # profile is still there untouched if Firefox ever disappoints.
    #
    # The profile is the existing ~/.mozilla/firefox/lando directory, left over
    # from the old (never-imported, therefore inert)
    # modules/home-manager/programs/firefox.nix.
    browser.firefox = {
      enable = true;

      # century-series is this host's Hyprland rice; the chrome follows it.
      personal.chromeTheme = "century-series";

      # The Homelab dashboard on the NAS, rather than Firefox Home. It is served
      # over HTTP, so anything added to it (feeds, status widgets) works without
      # a rebuild here and shows up on every device that opens it.
      #
      # Note this is the Home button and new windows, NOT startup: restoreSession
      # keeps browser.startup.page = 3, so launching Firefox reopens the previous
      # session. Not set as a module default — .lan does not resolve for
      # restricted VPN peers, so blaney-pc must not inherit it.
      personal.startup.homepage = "http://home.lan/";

      # Substitute the two tokened bookmark URLs from the sops secrets declared
      # in apps.nix.
      personal.bookmarks.secrets.enable = true;
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {
      # Spotify itself comes from customConfig.apps.programs.music; this entry only
      # adds the Wayland/Ozone flags to its desktop launcher.
      xdg.desktopEntries.spotify = {
        name = "Spotify";
        genericName = "Music Player";
        exec = "spotify --enable-features=UseOzonePlatform --ozone-platform=wayland %U";
        icon = "spotify";
        terminal = false;
        categories = [ "Audio" "Music" "Player" "AudioVideo" ];
        mimeType = [ "x-scheme-handler/spotify" ];
      };
      # Start-menu entry for the `webcam` wrapper (see apps.nix). Lands under Multimedia in
      # the Whisker menu. accessories-camera is a real icon in the Windows 7 Aero set (present
      # in every size tier), so it resolves at all menu/panel sizes.
      xdg.desktopEntries.webcam = {
        name = "Webcam";
        genericName = "Webcam Viewer";
        exec = "webcam";
        icon = "accessories-camera";
        terminal = false;
        categories = [ "AudioVideo" "Video" ];
      };
      # Override guvcview's own .desktop purely to fix its Start-menu icon. Upstream ships
      # `Icon=/nix/store/…/pixmaps/guvcview.png` — an ABSOLUTE PATH, which bypasses icon-theme
      # lookup entirely, so the alias_icon entry in windows7-xfce-gtk.nix cannot reach it (that
      # alias still earns its keep for the WM_CLASS-based taskbar button and titlebar icon).
      # Naming this entry `guvcview` shadows the system copy: /etc/profiles/per-user/lando/share
      # precedes /run/current-system/sw/share in XDG_DATA_DIRS, so this one wins.
      xdg.desktopEntries.guvcview = {
        name = "Webcam Controls";
        genericName = "Webcam Viewer";
        comment = "Capture and adjust exposure, focus and white balance";
        exec = "guvcview";
        icon = "accessories-camera";
        terminal = false;
        categories = [ "AudioVideo" "Video" ];
      };
      systemd.user.services.audio-spkr-balance = {
        Unit = {
          Description = "Set speaker balance compensation on SPKR output (pro-output-3)";
          After = [ "pipewire-pulse.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.pulseaudio}/bin/pactl set-sink-channel-volumes alsa_output.pci-0000_01_00.1.pro-output-3 80% 100%";
          Restart = "on-failure";
          RestartSec = "2";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
