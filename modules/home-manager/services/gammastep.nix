# ~/nixos-config/modules/home-manager/system/gammastep
{ pkgs, ... }:

{
  imports = [
    pkgs.geoclue2
  ];
  
  config = config.hmCustomConfig.services.gammastep {
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
  };
}
