# ~/nixos-config/hosts/blaney-pc/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true; # Enable Home Manager for this host
    # Notify at next login if a walk-away `rebuild-shutdown` failed.
    services.rebuildShutdownNotify.enable = true;
    themes = {
      plasmaOverride = true;
      kde = "windows7-alt";
      hyprland = "century-series";
      # Win7 XFCE session (X11) as a coexisting login choice — pick "Xfce Session" at Ly.
      # Fully declarative: every rebuild re-asserts the declared taskbar/theme.
      xfce = "windows7";
      wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
      # XFCE session gets the aviation wallpaper (matches his Hyprland/century-series, which
      # also falls back to f-15 since he has no desktop.monitors yet) while KDE keeps the Win7
      # wallpaper above. Once his desktop.monitors are set up on-target, portraits can get
      # carrier-top via per-monitor wallpaper.
      xfceWallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
      # XFCE taskbar mirrors the KDE pin set below, using themed/XFCE-native apps where the
      # KDE app has an equivalent (Konsole→kitty, Dolphin→Thunar, KCalc→galculator,
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
      pinnedApps = [
        "applications:org.kde.konsole.desktop"
        "applications:systemsettings.desktop"
        "applications:org.kde.dolphin.desktop"
        "applications:org.chromium.Chromium.desktop"
        "applications:net.lutris.Lutris.desktop"
        "applications:com.heroicgameslauncher.hgl.desktop"
        "applications:steam.desktop"
        "applications:com.discordapp.Discord.desktop"
        "applications:com.spotify.Client.desktop"
        "applications:org.kde.plasma-systemmonitor.desktop"
        "applications:org.kde.kcalc.desktop"
        "applications:polychromatic.desktop"
        "applications:input-remapper-gtk.desktop"
        "applications:openrgb.desktop"
        "applications:io.github.nuttyartist.notes.desktop"
      ];
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
