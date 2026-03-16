# ~/nixos-config/modules/home-manager/themes/plasma-bigsur.nix
{ lib, pkgs, config, customConfig, ... }:

let
  cfg = customConfig;
  isKdeEnabled = lib.elem "kde" cfg.desktop.environments;
  isThemeSelected = cfg.homeManager.themes.kde == "bigsur";

  # Absolute store paths for KDE tools so scripts work in any PATH context
  plasmaWs    = "${pkgs.kdePackages.plasma-workspace}/bin";
  kwritecfg6  = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  # Shell fragment: switch to WhiteSur light
  lightCmds = ''
    ${plasmaWs}/plasma-apply-colorscheme WhiteSur
    ${plasmaWs}/plasma-apply-desktoptheme WhiteSur-alt
    ${kwritecfg6} --file Kvantum/kvantum.kvconfig --group General --key theme WhiteSur
  '';

  # Shell fragment: switch to WhiteSur dark
  darkCmds = ''
    ${plasmaWs}/plasma-apply-colorscheme WhiteSurDark
    ${plasmaWs}/plasma-apply-desktoptheme WhiteSur-dark
    ${kwritecfg6} --file Kvantum/kvantum.kvconfig --group General --key theme WhiteSurDark
  '';

  # Script body: check hour and apply the appropriate variant
  autoThemeCmds = ''
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 20 ]; then
      ${lightCmds}
    else
      ${darkCmds}
    fi
  '';
in
{
  config = lib.mkIf (isKdeEnabled && isThemeSelected) {

    # 1. Install theme packages
    home.packages = with pkgs; [
      whitesur-kde
      whitesur-icon-theme
      whitesur-cursors
      whitesur-gtk-theme
      inter  # macOS San Francisco substitute
      # Note: kdePackages.sierra-breeze-enhanced is broken in current nixpkgs (Qt6::GuiPrivate missing).
      # WhiteSur uses its own aurorae window decorations so this isn't needed.
    ];

    # 2. Qt via Kvantum
    qt = {
      enable = true;
      style = {
        name = "kvantum";
        package = pkgs.kdePackages.qtstyleplugin-kvantum;
      };
    };

    fonts.fontconfig.enable = true;

    # 3. Create the Kvantum config as a regular (writable) file so the
    #    auto-switch scripts can update it at runtime.  xdg.configFile
    #    would produce a read-only nix-store symlink that kwriteconfig6
    #    cannot modify.
    home.activation.whitesurKvantumInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # If a previous deployment left a nix-store symlink here, remove it
      if [ -L "$HOME/.config/Kvantum/kvantum.kvconfig" ]; then
        $DRY_RUN_CMD rm "$HOME/.config/Kvantum/kvantum.kvconfig"
      fi
      $DRY_RUN_CMD mkdir -p "$HOME/.config/Kvantum"
      if [ ! -f "$HOME/.config/Kvantum/kvantum.kvconfig" ]; then
        $DRY_RUN_CMD printf '[General]\ntheme=WhiteSur\n' > "$HOME/.config/Kvantum/kvantum.kvconfig"
      fi
    '';

    # 4. Plasma-manager: layout, fonts, effects, panels
    programs.plasma = {
      enable = true;
      overrideConfig = cfg.homeManager.themes.plasmaOverride;

      # Apply the light look-and-feel on first deploy / config changes.
      # The whitesur-auto-theme startup script overrides this at every login.
      workspace.lookAndFeel = "com.github.vinceliuice.WhiteSur-alt";
      workspace.wallpaper    = cfg.homeManager.themes.wallpaper;

      configFile."kwinrc"."Compositing" = {
        Enabled = true;
        Backend = "OpenGL";
      };

      configFile."kdeglobals"."General" = {
        widgetStyle = "kvantum";
      };

      fonts = {
        general     = { family = "Inter"; pointSize = 10; };
        fixedWidth  = { family = "monospace"; pointSize = 10; };
        small       = { family = "Inter"; pointSize = 8; };
        toolbar     = { family = "Inter"; pointSize = 10; };
        menu        = { family = "Inter"; pointSize = 10; };
        windowTitle = { family = "Inter"; pointSize = 10; };
      };

      kwin = {
        effects.blur.enable    = true;
        effects.blur.strength  = 7;
      };

      panels = [
        # Top menu bar
        {
          location = "top";
          height   = 32;

          widgets = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.appmenu"
            "org.kde.plasma.panelspacer"

            {
              systemTray.items.shown = [
                "org.kde.plasma.volume"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.powerdevil"
                "org.kde.plasma.displayconfiguration"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.notifications"
              ];
            }

            {
              name   = "org.kde.plasma.digitalclock";
              config = {
                "Appearance" = {
                  autoFontAndSize    = false;
                  customDateFormat   = "ddd d";
                  dateDisplayFormat  = "BesideTime";
                  dateFormat         = "custom";
                  fontFamily         = "Inter";
                  fontWeight         = 400;
                  showDate           = true;
                };
              };
            }
          ];
        }

        # Bottom floating dock
        {
          location   = "bottom";
          height     = 56;
          floating   = true;
          alignment  = "center";
          lengthMode = "fit";

          widgets = [
            {
              iconTasks = {
                launchers = customConfig.homeManager.themes.pinnedApps;
              };
            }
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.trash"
          ];
        }
      ];

      # 5. Auto dark/light startup script.
      #    Runs at every Plasma login (runAlways = true).
      #    Priority 1 ensures it runs after plasma-manager's own apply_themes
      #    script (priority 0), so it always wins the final theme state.
      startup.startupScript."whitesur-auto-theme" = {
        priority   = 1;
        runAlways  = true;
        text       = autoThemeCmds;
      };
    };

    # 6. Systemd user timers for runtime switching during an active session.
    #    The startup script handles login-time state; these handle transitions
    #    while the user is already logged in.

    systemd.user.services.whitesur-to-light = {
      Unit.Description = "Switch WhiteSur to light theme";
      Service = {
        Type      = "oneshot";
        ExecStart = "${pkgs.writeShellScript "whitesur-to-light" lightCmds}";
      };
    };

    systemd.user.timers.whitesur-to-light = {
      Unit.Description = "Switch WhiteSur to light at 7 AM";
      Timer = {
        OnCalendar = "*-*-* 07:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.whitesur-to-dark = {
      Unit.Description = "Switch WhiteSur to dark theme";
      Service = {
        Type      = "oneshot";
        ExecStart = "${pkgs.writeShellScript "whitesur-to-dark" darkCmds}";
      };
    };

    systemd.user.timers.whitesur-to-dark = {
      Unit.Description = "Switch WhiteSur to dark at 8 PM";
      Timer = {
        OnCalendar = "*-*-* 20:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
