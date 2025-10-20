# ~/nixos-config/modules/home-manager/kde/default-functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  touchpadCfg = customConfig.hardware.peripherals.touchpad;
  
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;
  defaultPlasmaSettingsEnabled = customConfig.homeManager.system.plasmaDefaultSettings;

  screenOffTimeout = ((screensaverCfg.timeout*60) + 300);
in
{
  config = lib.mkIf (isKdeDesktop && defaultPlasmaSettingsEnabled) {
    programs.plasma = {
      enable = true;
      overrideConfig = customConfig.homeManager.themes.plasmaOverride;

      session.sessionRestore.restoreOpenApplicationsOnLogin = "whenSessionWasManuallySaved";

      kscreenlocker = {
        # --- LOGIC CORRECTION ---
        # Disable Plasma's autolock if our custom screensaver is ENABLED.
        autoLock = !screensaverCfg.enable;
        # Enable lock-on-resume if our custom screensaver is DISABLED.
        lockOnResume = !screensaverCfg.enable;
          timeout = if screensaverCfg.enable then null else 15;
      };

      # Power Management logic remains correct.
      powerdevil = {
        AC = {
          autoSuspend.action = "nothing";
          turnOffDisplay.idleTimeout = if screensaverCfg.enable then "never" else 900;
            whenLaptopLidClosed = "sleep";
        };
        battery = {
          autoSuspend.action = "sleep";
          turnOffDisplay.idleTimeout = if screensaverCfg.enable then screenOffTimeout else 600;
            whenLaptopLidClosed = "sleep";
        };
      };
 
      # Touchpad settings
      input.touchpads = lib.mkIf (touchpadCfg != null) [
        {
          # Pull the hardware info directly from our customConfig
          name = touchpadCfg.name;
          vendorId = touchpadCfg.vendorId;
          productId = touchpadCfg.productId;

          # Set natural scrolling to true
          naturalScroll = true;
        }
      ];
    };
  };
}