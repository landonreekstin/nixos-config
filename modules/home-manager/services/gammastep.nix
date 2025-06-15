# ~/nixos-config/modules/home-manager/system/gammastep
{ pkgs, ... }:

{
  services.gammastep = {
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
