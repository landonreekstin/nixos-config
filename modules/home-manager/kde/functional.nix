# ~/nixos-config/modules/home-manager/kde/functional.nix
{ lib, config, customConfig, ... }:

let
  screensaverCfg = customConfig.desktop.displayManager.sddm.screensaver;
  idleCfg = customConfig.desktop.idle;
  isKdeDesktop = lib.elem "kde" customConfig.desktop.environments;
  kdeCfg = customConfig.desktop.kde;

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
        autoSuspend.idleTimeout = if idleCfg.sleepTimeout != null then lib.max 60 idleCfg.sleepTimeout else null;
        # Turn off display at the same time as lock so kscreenlocker is already
        # the frontmost window when the display wakes — avoids the NVIDIA console flash.
        turnOffDisplay.idleTimeout =
          if screensaverCfg.enable then "never"
          else if idleCfg.lockTimeout != null then lib.max 30 idleCfg.lockTimeout
          else "never";
      };

      powerdevil.battery = {
        autoSuspend.action = if batterySleep != null then "sleep" else "nothing";
        autoSuspend.idleTimeout = if batterySleep != null then lib.max 60 batterySleep else null;
        turnOffDisplay.idleTimeout =
          if screensaverCfg.enable then "never"
          else if batteryLock != null then lib.max 30 batteryLock
          else "never";
      };

      configFile."kcminputrc"."LibinputPointer"."NaturalScroll" = customConfig.hardware.touchpad.naturalScroll;
      configFile."kwalletrc"."Wallet"."Enabled" = false;

      shortcuts = {
        kwin = {
          # Window management
          "Kill Window"                        = "Meta+Q";
          "Window Fullscreen"                  = "Meta+F11";
          "MinimizeAll"                        = "Meta+D";

          # Focus — vim-style + arrow-style (multi-binding via list)
          "Switch Window Left"                 = [ "Meta+H" "Ctrl+Left" ];
          "Switch Window Down"                 = [ "Meta+J" "Ctrl+Down" ];
          "Switch Window Up"                   = [ "Meta+K" "Ctrl+Up" ];
          "Switch Window Right"                = [ "Meta+L" "Ctrl+Right" ];

          # Monitor navigation (matches Ctrl+Super+Left/Right / Super+Shift+Left/Right)
          "Switch to Next Screen"              = "Meta+Ctrl+Right";
          "Switch to Previous Screen"          = "Meta+Ctrl+Left";
          "Move Window to Next Screen"         = "Meta+Shift+Right";
          "Move Window to Previous Screen"     = "Meta+Shift+Left";

          # Workspace navigation (matches Ctrl+Super+Up/Down)
          "Switch to Next Virtual Desktop"     = "Meta+Ctrl+Up";
          "Switch to Previous Virtual Desktop" = "Meta+Ctrl+Down";

          # Window task switcher (Alt+Tab style)
          "Walk Through Windows Alternative"   = "Meta+Tab";
        }
        # Workspace switching: Super+1-9 / Super+Shift+1-9
        // (builtins.listToAttrs (
          map (n: { name = "Switch to Desktop ${toString n}"; value = "Meta+${toString n}"; })
              (lib.range 1 9)
        ))
        // (builtins.listToAttrs (
          map (n: { name = "Window to Desktop ${toString n}"; value = "Meta+Shift+${toString n}"; })
              (lib.range 1 9)
        ))
        // {
          "Switch to Desktop 10"               = "Meta+0";
          "Window to Desktop 10"               = "Meta+Shift+0";
        };

        # App launcher (matches Super+Space → rofi)
        krunner = {
          "_launch" = "Meta+Space";
        };

        # Lock screen (matches Super+Escape → swaylock)
        ksmserver = {
          "Lock Session" = "Meta+Escape";
        };

        # Screenshot region (matches Super+Shift+S → grim+slurp)
        "org.kde.spectacle" = {
          "RectangularRegionScreenshot" = "Meta+Shift+S";
        };

        # Terminal launch (matches Super+Return — configurable per host via customConfig.desktop.kde.terminalApp)
        "${kdeCfg.terminalApp}" = {
          "_launch" = "Meta+Return";
        };
      };
    };
  };
}