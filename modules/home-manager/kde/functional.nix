# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  idleCfg = customConfig.desktop.idle;
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;

  # Resolve battery timeouts, falling back to AC values when not set.
  batteryLock  = if idleCfg.battery.lockTimeout  != null then idleCfg.battery.lockTimeout  else idleCfg.lockTimeout;
  batterySleep = if idleCfg.battery.sleepTimeout != null then idleCfg.battery.sleepTimeout else idleCfg.sleepTimeout;

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
        autoLock = !screensaverCfg.enable && idleCfg.lockTimeout != null;
        lockOnResume = !screensaverCfg.enable;
        # plasma-manager expects minutes; divide seconds by 60
        timeout = if (screensaverCfg.enable || idleCfg.lockTimeout == null)
                  then null
                  else idleCfg.lockTimeout / 60;
      };

      powerdevil.AC = {
        autoSuspend.action = if idleCfg.sleepTimeout != null then "sleep" else "nothing";
        # plasma-manager requires idleTimeout >= 60; clamp to satisfy the constraint
        autoSuspend.idleTimeout = if idleCfg.sleepTimeout != null then lib.max 60 idleCfg.sleepTimeout else null;
        # Turn off display at sleepTimeout (after lock), so kscreenlocker is
        # already rendered when the screen wakes — avoids showing kernel console.
        # Falls back to lockTimeout if sleepTimeout is null. Clamp to min 30s.
        turnOffDisplay.idleTimeout =
          if screensaverCfg.enable then "never"
          else if idleCfg.sleepTimeout != null then lib.max 30 idleCfg.sleepTimeout
          else if idleCfg.lockTimeout != null then lib.max 30 idleCfg.lockTimeout
          else "never";
      };

      powerdevil.battery = {
        autoSuspend.action = if batterySleep != null then "sleep" else "nothing";
        autoSuspend.idleTimeout = if batterySleep != null then lib.max 60 batterySleep else null;
        turnOffDisplay.idleTimeout =
          if screensaverCfg.enable then "never"
          else if batterySleep != null then lib.max 30 batterySleep
          else if batteryLock != null then lib.max 30 batteryLock
          else "never";
      };
    };
  };
}