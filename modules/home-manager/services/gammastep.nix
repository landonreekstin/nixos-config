# ~/nixos-config/modules/home-manager/system/gammastep
{ config, lib, customConfig, ... }:

{

  services.gammastep = lib.mkIf (customConfig.homeManager.enable && customConfig.homeManager.services.gammastep.enable) {
    enable = true;
    provider = "geoclue2";
    tray = true;
    temperature = {
      night = 2500;
    };
    # Optional: Enable verbose logging for troubleshooting
    # enableVerboseLogging = true;
  };
}
