# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  idleCfg = customConfig.desktop.idle;
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
        autoLock = !screensaverCfg.enable && idleCfg.lockTimeout != null;
        lockOnResume = !screensaverCfg.enable;
        # plasma-manager expects minutes; divide seconds by 60
        timeout = if (screensaverCfg.enable || idleCfg.lockTimeout == null)
                  then null
                  else idleCfg.lockTimeout / 60;
      };

      powerdevil.AC = {
        autoSuspend.action = if idleCfg.sleepTimeout != null then "sleep" else "nothing";
        autoSuspend.idleTimeout = idleCfg.sleepTimeout;
        turnOffDisplay.idleTimeout = if screensaverCfg.enable then "never"
                                     else if idleCfg.lockTimeout != null then idleCfg.lockTimeout
                                     else "never";
      };
    };
  };
}