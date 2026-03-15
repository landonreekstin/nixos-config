# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;

  kdeAutostart = lib.filter (app:
    app.desktops == [] || lib.elem "kde" app.desktops
  ) customConfig.desktop.autostart;

  mkDesktopEntry = app:
    let
      name = lib.last (lib.splitString "/" (lib.head (lib.splitString " " app.command)));
    in {
      name = "autostart/${name}.desktop";
      value.text = ''
        [Desktop Entry]
        Type=Application
        Exec=${app.command}
        Name=${name}
        X-KDE-AutostartPhase=2
      '';
    };
in
{
  config = lib.mkIf (isKdeDesktop) {
    xdg.configFile = lib.listToAttrs (map mkDesktopEntry kdeAutostart);

    programs.plasma = {
      enable = true;

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