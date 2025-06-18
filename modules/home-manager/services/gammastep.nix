# ~/nixos-config/modules/home-manager/system/gammastep
{ config, lib, ... }:

{

  services.gammastep = lib.mkIf config.hmCustomConfig.services.gammastep {
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
