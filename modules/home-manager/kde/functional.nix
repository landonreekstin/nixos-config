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
      configFile."kwalletrc"."Wallet"."Enabled" =
        lib.mkIf (!customConfig.desktop.kde.kwallet.enable) false;

      # Virtual desktops backing the Meta+1..0 switch/move shortcuts below. KDE ships a
      # single desktop by default, so those shortcuts would otherwise have no target.
      # Mirrors the Hyprland workspace layout (1-10).
      kwin.virtualDesktops = {
        number = 10;
        rows = 2;
      };

      shortcuts = {
        kwin = {
          # Window management
          "Kill Window"                        = "Meta+Q";
          "Window Fullscreen"                  = "Meta+F11";
          "MinimizeAll"                        = "Meta+D";
          "Show Desktop"                       = [];  # Clear default Meta+D peek — MinimizeAll owns Meta+D

          # Focus — vim-style + arrow-style (multi-binding via list)
          "Switch Window Left"                 = [ "Meta+H" "Ctrl+Left" ];
          "Switch Window Down"                 = [ "Meta+J" "Ctrl+Down" ];
          "Switch Window Up"                   = [ "Meta+K" "Ctrl+Up" ];
          "Switch Window Right"                = [ "Meta+L" "Ctrl+Right" ];

          # Monitor focus (matches Ctrl+Super+Left/Right in Hyprland)
          # Clear conflicting KDE defaults (Switch One Desktop to Left/Right) that share these keys
          "Switch to Next Screen"              = "Meta+Ctrl+Right";
          "Switch to Previous Screen"          = "Meta+Ctrl+Left";
          "Switch One Desktop to the Right"    = [];
          "Switch One Desktop to the Left"     = [];

          # Move window to adjacent monitor (matches Super+Shift+Left/Right)
          # KDE action ID is "Window to Next/Previous Screen"
          "Window to Next Screen"              = "Meta+Shift+Right";
          "Window to Previous Screen"          = "Meta+Shift+Left";
          # Clear stale aliases for the above from earlier builds
          "Move Window to Next Screen"         = [];
          "Move Window to Previous Screen"     = [];

          # Workspace navigation (Meta+Ctrl+Up/Down) — KDE default "Switch One Desktop Up/Down" already owns these
          # Clear stale alternate action names so no conflict occurs
          "Switch to Next Virtual Desktop"     = [];
          "Switch to Previous Virtual Desktop" = [];

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

        # App launcher: intentionally unbound — KDE already opens KRunner on the bare Meta
        # key, so a separate Meta+Space (Hyprland's rofi bind) is redundant here.

        # Lock screen (matches Super+Escape → swaylock)
        ksmserver = {
          "Lock Session" = "Meta+Escape";
        };
      };

      # Screenshot region (matches Super+Shift+S → grim+slurp). Use the dedicated spectacle
      # module: it targets the correct component (services/org.kde.spectacle.desktop) and
      # action id (RectangularRegionScreenShot). The earlier raw shortcuts entry had the
      # wrong component and mis-cased action ("...Screenshot"), so it never bound.
      spectacle.shortcuts.captureRectangularRegion = "Meta+Shift+S";

      # Meta+Return → terminal. Bind a command hotkey rather than the app's own `_launch`
      # action: `_launch` only sticks once the app has registered itself with kglobalaccel,
      # so declaring it up-front is unreliable (the earlier D-Bus re-register hack never
      # landed). A command hotkey registers a hidden desktop entry + kglobalshortcutsrc
      # mapping that kglobalaccel binds directly. `kstart --application` launches the
      # configured terminal via its desktop file (default org.kde.konsole).
      hotkeys.commands."launch-terminal" = {
        name = "Launch Terminal";
        key = "Meta+Return";
        command = "kstart --application ${kdeCfg.terminalApp}";
      };
    };
  };
}