{ lib, config, customConfig, ... }:

let
  cfg = customConfig;
  isKdeEnabled = lib.elem "kde" cfg.desktop.environments;
  isThemeSelected = cfg.homeManager.themes.kde == "default";
in
{
  config = lib.mkIf (isKdeEnabled && isThemeSelected) {

    programs.plasma = {
      enable = true;
      overrideConfig = customConfig.homeManager.themes.plasmaOverride;

      # Set wallpaper only if the customConfig option is defined
      workspace = lib.mkIf (cfg.homeManager.themes.wallpaper != null) {
        wallpaper = cfg.homeManager.themes.wallpaper;
      };

      panels = [{
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"

          {
            iconTasks = {
              launchers = customConfig.homeManager.themes.pinnedApps;
            };
          }

          "org.kde.plasma.panelspacer"

          # Weather widget placed before the system tray
          "org.kde.plasma.weather"

          # System tray
          {
            systemTray.items.shown = [
              "org.kde.plasma.volume"
              "org.kde.plasma.powerdevil"       # Brightness
              "org.kde.plasma.bluetooth"
              "org.kde.plasma.networkmanagement"
              "org.kde.plasma.devicenotifier"   # Disks and Drives
            ];
          }
          "org.kde.plasma.digitalclock"
        ];
      }];
    };
  };
}