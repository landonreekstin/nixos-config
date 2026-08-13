# ~/nixos-config/hosts/vm-blaney/home.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  customConfig.homeManager = {
    enable = true;
    # Mirror blaney-pc: notify at next login if a walk-away rebuild-shutdown failed.
    services.rebuildShutdownNotify.enable = true;
    themes = {
      plasmaOverride = true;
      kde = "windows7-alt";      # aerothemeplasma — the thing we're here to test
      hyprland = "century-series";
      # XFCE windows7 taskbar — mirror blaney-pc EXACTLY so the pre-PR VM check shows his
      # real taskbar (pick "Xfce Session" at Ly). Keep this identical to hosts/blaney-pc.
      xfce = "windows7";
      wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
      # Mirror blaney-pc: XFCE gets the aviation wallpaper (no desktop.monitors → f-15 on all),
      # KDE keeps Win7.
      xfceWallpaper = ../../assets/wallpapers/f-15-satellite.jpg;
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
        "applications:org.kde.plasma-systemmonitor.desktop"
        "applications:org.kde.kcalc.desktop"
      ];
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}
