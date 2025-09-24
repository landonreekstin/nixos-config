# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  # A reference to the custom screensaver options we defined.
  # `customConfig` is available here because you passed it via `extraSpecialArgs`.
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;

  # A helper to check if KDE is one of the enabled desktop environments.
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;
in
{
    config = lib.mkIf (isKdeDesktop) {

        programs.plasma = {
            enable = true;
            kscreenlocker = {
                # disable KDE's built-in idle timer to prevent it from conflicting with `xautolock` screensaver service.
                autoLock = screensaverCfg.enable;
                lockOnResume = !screensaverCfg.enable;
                timeout = if screensaverCfg.enable then null else 25; # In minutes
            };

            # Power Management
            powerdevil.AC = {
                autoSuspend = {
                    action = "nothing";
                };
                # Only turn off display if screensaver is disabled
                turnOffDisplay = lib.mkIf !screensaverCfg.enable {
                    idleTimeout = 900; # 15 minutes in seconds
                };
            };
        };
    };
}