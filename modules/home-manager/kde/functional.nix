# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, customConfig, ... }:

let
  # A reference to the custom screensaver options we defined.
  # `customConfig` is available here because you passed it via `extraSpecialArgs`.
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;

  # A helper to check if KDE is one of the enabled desktop environments.
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;
in
{
  # We only apply these settings if the user is on a KDE desktop
  # AND has enabled the custom SDDM screensaver in their host config.
  config = lib.mkIf (isKdeDesktop && screensaverCfg.enable) {

    # Enable plasma-manager so we can configure its settings.
    programs.plasma.enable = true;

    # Configure the kscreenlocker component of plasma-manager.
    programs.plasma.kscreenlocker = {
      # This is the key part: we disable KDE's built-in idle timer
      # to prevent it from conflicting with our `xautolock` service.
      autoLock = false;
    };
  };
}