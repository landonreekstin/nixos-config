# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;
  defaultPlasmaSettingsEnabled = customConfig.homeManager.system.plasmaDefaultSettings;
in
{
  config = lib.mkIf (isKdeDesktop && defaultPlasmaSettingsEnabled) {
    programs.plasma = {
      enable = true;
      overrideConfig = cfg.homeManager.themes.plasmaOverride;

      session.sessionRestore.restoreOpenApplicationsOnLogin = "whenSessionWasManuallySaved";

      kscreenlocker = {
        # --- LOGIC CORRECTION ---
        # Disable Plasma's autolock if our custom screensaver is ENABLED.
        autoLock = !screensaverCfg.enable;
        # Enable lock-on-resume if our custom screensaver is DISABLED.
        lockOnResume = !screensaverCfg.enable;
        # Set a default timeout only if our custom screensaver is DISABLED.
        timeout = if screensaverCfg.enable then null else 15; # 15 minutes
      };

      # Power Management logic remains correct.
      powerdevil.AC = {
        autoSuspend.action = "nothing";
        turnOffDisplay.idleTimeout = if screensaverCfg.enable then "never" else 900; # 15 minutes in seconds
      };
    };
  };
}