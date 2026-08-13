# ~/nixos-config/modules/nixos/common/home-manager.nix
{ inputs, lib, config, ... }:
{
  options.customConfig.homeManager = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true; # Generally, if using this structure, HM is enabled for the user.
      description = "Whether Home Manager is configured for the primary user.";
    };
    services = {
      hyprsunset = {
        enable = mkOption {
          type = types.bool;
          default = (lib.elem "hyprland" config.customConfig.desktop.environments);
          description = "Whether to enable night light (hyprsunset) for Hyprland.";
        };
        nightTemp = mkOption {
          type = types.int;
          default = 2500;
          description = "Default night temperature in Kelvin (1000–6500). Adjustable at runtime via waybar scroll.";
        };
        dayTemp = mkOption {
          type = types.int;
          default = 6500;
          description = "Day temperature in Kelvin applied during daytime hours.";
        };
        transitionMinutes = mkOption {
          type = types.int;
          default = 30;
          description = "Duration of gradual day/night transitions in minutes (scheduled timer only).";
        };
        dayStartHour = mkOption {
          type = types.int;
          default = 7;
          description = "Hour (0–23) when daytime begins and day temperature is applied.";
        };
        nightStartHour = mkOption {
          type = types.int;
          default = 20;
          description = "Hour (0–23) when nighttime begins and night temperature is applied.";
        };
      };
      updateNotification = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable a once-per-login desktop notification when the nixos-config repo has upstream updates.";
        };
      };
      rebuildShutdownNotify = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Show a critical desktop notification at next login if the last `rebuild-shutdown` failed. Enable on hosts where rebuild-shutdown is used unattended.";
        };
      };
    };
    themes = {
      kde = mkOption {
        type = types.enum [ "windows7" "windows7-alt" "default" "bigsur" "none" ];
        default = "none";
        description = "Set the Plasma theme for Home Manager.";
      };
      plasmaOverride = mkEnableOption "Override user-session set Plasma configuration.";
      hyprland = mkOption {
        type = types.enum [ "future-aviation" "century-series" "none" ];
        default = "none";
        description = "Set the Hyprland theme for Home Manager.";
      };
      xfce = mkOption {
        type = types.enum [ "windows7" "none" ];
        default = "none";
        description = "Set the XFCE theme for Home Manager.";
      };
      xfcePanel = {
        pinnedApps = mkOption {
          type = with types; listOf (submodule {
            options = {
              name = mkOption { type = str; description = "Launcher label (shown as tooltip)."; };
              exec = mkOption { type = str; description = "Command to launch."; };
              icon = mkOption { type = str; description = "Icon name or absolute path."; };
            };
          });
          default = [];
          description = ''
            Icon-only app launchers pinned to the XFCE (windows7) taskbar, ordered
            left→right (the Win7 analog of homeManager.themes.pinnedApps for KDE).
          '';
          example = lib.literalExpression ''
            [ { name = "Files"; exec = "thunar"; icon = "system-file-manager"; } ]
          '';
        };
        trayApplets = mkOption {
          type = with types; listOf (enum [ "network" "bluetooth" "power" "clipboard" "nightlight" ]);
          default = [ "network" ];
          description = ''
            Status-notifier applets autostarted into the XFCE systray, left→right:
            network (nm-applet), bluetooth (blueman), power (xfce4-power-manager),
            clipboard (xfce4-clipman), nightlight (redshift-gtk — day/night color temp).
          '';
        };
        iconSize = mkOption {
          type = types.ints.between 16 48;
          default = 28;
          description = "Panel icon size (px) for the XFCE windows7 taskbar.";
        };
        nightlight = {
          tempDay = mkOption {
            type = types.ints.between 1000 25000;
            default = 6500;
            description = "Daytime color temperature (K) for the nightlight (redshift) applet.";
          };
          tempNight = mkOption {
            type = types.ints.between 1000 25000;
            default = 3500;
            description = "Nighttime color temperature (K); lower = warmer.";
          };
          latitude = mkOption {
            type = types.float;
            default = 41.88;
            description = "Latitude for redshift's manual day/night transition (default: Chicago).";
          };
          longitude = mkOption {
            type = types.float;
            default = -87.63;
            description = "Longitude for redshift's manual day/night transition.";
          };
        };
      };
      wallpaper = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Absolute path to the desktop wallpaper. If null, a default will be used.";
        example = "/path/to/my/wallpaper.png";
      };
      xfceWallpaper = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Landscape wallpaper for the XFCE windows7 session only, overriding the global
          `wallpaper` there. Lets a host give XFCE a different (e.g. aviation) wallpaper than
          its KDE aerotheme without changing the shared `wallpaper`. Portrait monitors still
          use the vertical default (carrier-top); per-monitor `desktop.monitors.*.wallpaper`
          overrides both. If null, XFCE falls back to `wallpaper`.
        '';
        example = literalExpression "../../assets/wallpapers/f-15-satellite.jpg";
      };
      pinnedApps = mkOption {
        type = with types; listOf str;
        default = [
          "applications:systemsettings.desktop"
          "applications:org.kde.konsole.desktop"
          "applications:org.kde.kcalc.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:firefox.desktop"
          "applications:chromium-browser.desktop"
        ];
        description = "List of desktop file entries to pin to the taskbar/iconTasks widget.";
        example = ''
          [
            "applications:firefox.desktop"
            "applications:org.kde.konsole.desktop"
            "applications:code.desktop"
          ]
        '';
      };
    };
    # You can add more themes here later, e.g., 'cosmic', 'kde', etc.
    librewolf = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the declarative Librewolf browser profile preset.";
      };
      profilePath = mkOption {
        type = types.str;
        default = "rbb3lgdy.default";
        description = "LibreWolf profile directory name under ~/.librewolf/. Run 'ls ~/.librewolf/' to find the correct value.";
      };
      overrideConfig = mkOption {
        type = types.bool;
        default = true;
        description = ''
          When true, user.js is managed by HM and enforced every browser restart.
          When false, user.js is written only once (if absent) and user edits persist.
          Extensions and userChrome.css are always managed regardless of this setting.
        '';
      };
    };
  };

  config = {
    home-manager = {
      # Overwrite existing .hm-backup files on each rebuild instead of failing.
      # Without this, HM fails when a backup file already exists from a previous run.
      overwriteBackup = true;

      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      # Load the shared HM module set for every managed user on every host.
      sharedModules = [
        inputs.plasma-manager.homeModules.plasma-manager
        ../../home-manager/default.nix
      ];
    };
  };
}
