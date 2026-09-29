# ~/nixos-config/hosts/blaney-pc/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true; # Enable Home Manager for this host
    # Notify at next login if a walk-away `rebuild-shutdown` failed.
    services.rebuildShutdownNotify.enable = true;
    # Warn before a shutdown that would cancel the weekly unattended update
    # (customConfig.services.autoUpdate in ./networking.nix — this host powers off afterwards,
    # so it has to be left on). Silent unless the update is due within warnWithinHours.
    services.shutdownGuard.enable = true;
    themes = {
      hyprland = "century-series";
      # The Win7 XFCE session (X11) is this machine's desktop. KDE was dropped from
      # desktop.environments along with aerothemeplasma — the Windows 7 look lives
      # entirely in modules/{nixos,home-manager}/themes/windows7-xfce/ now, which
      # compiles nothing. Fully declarative: every rebuild re-asserts the declared
      # taskbar/theme.
      xfce = "windows7";
      # The aviation wallpaper matches his Hyprland/century-series session (which also
      # falls back to f-15 since he has no desktop.monitors yet). Once his
      # desktop.monitors are set up on-target, portraits can get carrier-top via
      # per-monitor wallpaper.
      xfceWallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
      # XFCE taskbar pins, using themed/XFCE-native apps where a KDE app used to be the
      # equivalent (Konsole→kitty, Dolphin→Thunar, KCalc→galculator,
      # plasma-systemmonitor→xfce4-taskmanager, systemsettings→xfce4-settings-manager,
      # Notes→xpad); gaming/peripheral apps reused as-is. The org.xfce.*/galculator icons
      # resolve to Aero via the icon-alias step in windows7-xfce-gtk.nix.
      xfcePanel = {
        trayApplets = [ "network" "bluetooth" "power" "clipboard" ];
        pinnedApps = [
          { name = "Terminal";        exec = "kitty";                              icon = "kitty"; }
          { name = "System Settings"; exec = "xfce4-settings-manager";             icon = "org.xfce.settings.manager"; }
          { name = "Files";           exec = "thunar";                             icon = "system-file-manager"; }
          { name = "Chromium";        exec = "flatpak run org.chromium.Chromium";  icon = "internet-web-browser"; }
          { name = "Lutris";          exec = "lutris";                             icon = "net.lutris.Lutris"; }
          { name = "Heroic";          exec = "heroic";                             icon = "com.heroicgameslauncher.hgl"; }
          { name = "Steam";           exec = "steam";                              icon = "steam"; }
          { name = "Discord";         exec = "flatpak run com.discordapp.Discord"; icon = "com.discordapp.Discord"; }
          { name = "Spotify";         exec = "flatpak run com.spotify.Client";     icon = "com.spotify.Client"; }
          { name = "System Monitor";  exec = "xfce4-taskmanager";                  icon = "org.xfce.taskmanager"; }
          { name = "Calculator";      exec = "galculator";                         icon = "galculator"; }
          { name = "Polychromatic";   exec = "polychromatic-controller";           icon = "polychromatic"; }
          { name = "Input Remapper";  exec = "input-remapper-gtk";                 icon = "input-remapper"; }
          { name = "OpenRGB";         exec = "openrgb";                            icon = "OpenRGB"; }
          { name = "Notes";           exec = "xpad";                               icon = "xpad"; }
        ];
      };
    };

    # Firefox, installed ALONGSIDE the Flatpak Chromium that still owns Super+B,
    # the XFCE default and the panel pin. Nothing insideabush relies on
    # moves under him — he reaches Firefox from the app menu until this has been
    # looked at on the machine. Same soak approach that was used on gaming-pc.
    #
    # ownsAppRole = false keeps the browser role pointing at Chromium; without
    # it the config block in modules/nixos/apps/programs.nix would force the
    # role's command to "firefox".
    browser.firefox = {
      enable = true;
      ownsAppRole = false;

      # This host runs the Windows 7 theme in its XFCE session.
      personal.chromeTheme = "windows7";

      personal.bookmarks = {
        # The shared tree is lando's — his homelab, his mail, and two URLs whose
        # tokens live in secrets/gaming-pc.yaml and would render here as a
        # literal @DASHBOARD_TOKEN@. This host gets its own set instead.
        sharedTree = false;

        # A deliberately small starter set. insideabush is a restricted VPN peer,
        # so the homelab entries use the legacy 192.168.1.76 alias and explicit
        # ports: that is the only NAS address his AllowedIPs routes, and .lan
        # names do not resolve for restricted peers (they use 1.1.1.1 for DNS).
        # See docs/networking.md "VPN peer addressing".
        #
        # What actually belongs here is his call, not ours — see the runbook
        # task in TASKS.md. Treat this as a placeholder that works, not a
        # finished set.
        extra = [
          { name = "YouTube";  url = "https://www.youtube.com/"; }
          { name = "Netflix";  url = "https://www.netflix.com/browse"; }
          { name = "Jellyfin"; url = "http://192.168.1.76:8096/"; }
          { name = "Requests"; url = "http://192.168.1.76:5055/"; }
          { name = "Gaming"; bookmarks = [
              { name = "ProtonDB"; url = "https://www.protondb.com/"; }
              { name = "Steam";    url = "https://store.steampowered.com/"; }
            ]; }
        ];
      };
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
