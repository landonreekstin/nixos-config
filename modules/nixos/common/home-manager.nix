# ~/nixos-config/modules/nixos/common/home-manager.nix
{ inputs, lib, config, ... }:

let
  # Option tree shared by customConfig.homeManager.browser.{firefox,librewolf}.
  # The two Home Manager browser modules are generated from the same upstream
  # mkFirefoxModule.nix and expose identical options, so the presets in
  # modules/home-manager/programs/browser/ drive both from one definition and
  # the host-facing options are declared once here.
  #
  # Declared on the NixOS side because Home Manager receives customConfig as a
  # plain attrset through extraSpecialArgs rather than as its own option tree,
  # so HM modules in this repo cannot declare options at all — see the header
  # of modules/nixos/apps/programs.nix.
  mkBrowserOptions = { browserName, defaultProfilePath }: with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the declarative ${browserName} profile presets.";
    };

    profilePath = mkOption {
      type = types.str;
      default = defaultProfilePath;
      description = ''
        Profile directory name under the browser's config dir. An existing
        profile is adopted rather than replaced — run `ls ~/.mozilla/firefox/`
        or `ls ~/.librewolf/` to find the current value.
      '';
    };

    overrideConfig = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When true, preset prefs are written to the profile's user.js and
        re-enforced at every browser start, so a change made in the browser UI
        reverts on restart.

        When false, they are compiled into the package's autoconfig as
        defaultPref(), so they act as defaults and a UI change persists. This
        is the same mechanism LibreWolf uses for its own settings.

        Extensions, userChrome.css, bookmarks, search and containers are
        managed declaratively either way.
      '';
    };

    ownsAppRole = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether this browser is the one on customConfig.apps.programs.browser.

        When true, the role's `command` is forced to the bare binary name so
        Super+B and the launcher buttons reach the *wrapped* build this module
        produces rather than the unwrapped store path (see the config block in
        modules/nixos/apps/programs.nix).

        Set false when a host configures this browser but drives the role with
        a different one — gaming-pc manages Firefox declaratively while Super+B
        still opens its hand-configured LibreWolf.

        This cannot be detected automatically: deciding it from
        apps.programs.browser.package would make defining browser.command
        depend on reading a sibling of the same submodule, which is infinite
        recursion.
      '';
    };

    extraSettings = mkOption {
      type = with types; attrsOf (oneOf [ bool int str ]);
      default = { };
      description = "Extra about:config prefs, merged over both presets.";
      example = literalExpression ''{ "browser.tabs.inTitlebar" = 0; }'';
    };

    # ── Privacy layer ──────────────────────────────────────────────────────
    privacy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Apply the LibreWolf-equivalent hardening preset: telemetry and
          studies off, strict tracking protection, Global Privacy Control, no
          speculative connections, trimmed referers, TLS hardening,
          geolocation off, no sponsored content, plus the privacy extensions.
        '';
      };

      sanitizeOnShutdown = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Clear cookies and site storage when the browser closes, as LibreWolf
          does. Off by default: it is the single biggest usability cost, since
          every login dies with the browser.
        '';
      };

      disableSafeBrowsing = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Strip Safe Browsing entirely, as LibreWolf does. Off by default — it
          removes malware and phishing protection, not just the Google lookups.
        '';
      };

      promptDownloadDir = mkOption {
        type = types.bool;
        default = false;
        description = "Ask where to save every download instead of using downloadDir.";
      };

      downloadDir = mkOption {
        type = types.str;
        default = "${config.customConfig.user.home}/Downloads";
        defaultText = literalExpression ''"''${customConfig.user.home}/Downloads"'';
        description = "Fixed download directory, used when promptDownloadDir is false.";
      };

      resistFingerprinting = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable privacy.resistFingerprinting. Off by default: it forces a
          light theme and a fixed window size, and breaks canvas and font
          rendering on many sites.
        '';
      };

      httpsOnlyMode = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable HTTPS-only mode. Off by default because the homelab
          (jellyfin.lan, radarr.lan, …) is served over plain HTTP.
        '';
      };

      useSystemDNS = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Set network.trr.mode = 5 — DoH explicitly off, use the system
          resolver. Required for .lan: DoH bypasses the local Unbound resolver
          and .lan stops resolving.
        '';
      };

      rememberPasswords = mkOption {
        type = types.bool;
        default = true;
        description = "Let the browser save and autofill logins. LibreWolf disables this.";
      };

      enableDRM = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable EME/Widevine so Netflix, Prime Video and similar play.
          LibreWolf blocks the GMP manager outright.
        '';
      };

      allowAutoplay = mkOption {
        type = types.bool;
        default = true;
        description = "Allow media autoplay. LibreWolf blocks it entirely.";
      };

      extraExtensions = mkOption {
        type = with types; listOf package;
        default = [ ];
        description = "Extra add-on packages installed alongside the privacy set.";
        example = literalExpression ''
          with pkgs.nur.repos.rycee.firefox-addons; [ privacy-badger ]
        '';
      };
    };

    # ── Personal layer ─────────────────────────────────────────────────────
    personal = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Apply the personal preset: bookmarks, chrome theme, search engines,
          containers and startup behaviour. Independent of the privacy layer —
          either can be enabled without the other.
        '';
      };

      chromeTheme = mkOption {
        type = types.enum [ "catppuccin-mocha" "century-series" "windows7" "none" ];
        default = "catppuccin-mocha";
        description = ''
          userChrome.css theme for the toolbar, urlbar and tabs. The files live
          in modules/home-manager/programs/browser/chrome/.
        '';
      };

      bookmarks = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Manage the bookmarks toolbar declaratively.";
        };

        toolbarVisibility = mkOption {
          type = types.enum [ "always" "never" "newtab" ];
          default = "always";
          description = "When to show the bookmarks toolbar.";
        };

        sharedTree = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Include the shared bookmark tree from
            modules/home-manager/programs/browser/bookmarks.nix.

            That tree is lando's, read out of his LibreWolf profile — his
            homelab, his mail, and two URLs whose tokens only exist in
            secrets/gaming-pc.yaml. Set false on a host belonging to someone
            else and supply their own set through `extra`.
          '';
        };

        extra = mkOption {
          type = types.anything;
          default = [ ];
          description = "Host-specific bookmarks, appended to the shared tree when sharedTree is on.";
        };

        secrets = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Substitute the @PLACEHOLDER@ tokens in the shared bookmark tree
              from sops secrets at activation.

              Two bookmarks embed a credential in their URL. Home Manager
              renders bookmarks.html into the Nix store, which is
              world-readable — and this repo is public — so the tokens live
              only in sops and are written into a copy under $HOME.

              The host must declare the matching sops.secrets with
              owner = <user> so the user-level activation can read them.
            '';
          };

          directory = mkOption {
            type = types.str;
            default = "/run/secrets";
            description = "Directory sops-nix renders the bookmark secrets into.";
          };
        };
      };

      containers = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Manage the container set declaratively. This writes
            containers.json with force, replacing any containers created in
            the browser, so it is worth turning off on a host whose profile
            was set up by hand.
          '';
        };
      };

      search = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Manage search engines and the default engine declaratively.";
        };

        default = mkOption {
          type = types.str;
          default = "DuckDuckGo No-AI";
          description = ''
            Name of the default engine. Must be a key of the engine set in
            modules/home-manager/programs/browser/personal.nix.
          '';
        };
      };

      startup = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Manage startup, new-tab and dark-theme prefs.";
        };

        restoreSession = mkOption {
          type = types.bool;
          default = true;
          description = "Reopen the previous session's windows and tabs on start.";
        };

        homepage = mkOption {
          type = types.str;
          default = "about:home";
          description = ''
            Homepage URL. Used by the home button, and on start when
            restoreSession is false.
          '';
        };

        newTabPage = mkOption {
          type = types.enum [ "firefox-home" "blank" ];
          default = "firefox-home";
          description = ''
            What a new tab shows. Sponsored tiles and stories are off either
            way — that is handled by the privacy layer.
          '';
        };
      };

      extraExtensions = mkOption {
        type = with types; listOf package;
        default = [ ];
        description = "Extra add-on packages installed alongside the personal set.";
      };
    };
  };
in
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
      shutdownGuard = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Warn before a desktop shutdown that would cancel an imminent automated update.
            Only meaningful alongside `customConfig.services.autoUpdate.enable`; the guard is
            silent (and exits "go ahead") whenever no update is due inside the warning window.
          '';
        };
        warnWithinHours = mkOption {
          type = types.int;
          default = 12;
          description = "Show the warning only when the next automated update is due within this many hours.";
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
    # ── Browsers ───────────────────────────────────────────────────────────
    # Both entries take the same preset submodules, built by mkBrowserOptions
    # at the top of this file. Implemented by
    # modules/home-manager/programs/browser/.
    #
    # Firefox exists as the escape hatch from LibreWolf's packaging: nixpkgs
    # periodically marks LibreWolf insecure, Hydra then stops building it, and
    # any host that has not pinned it to unstable source-builds a Firefox fork —
    # which is what keeps stalling the weekly flake-update PRs.
    browser = {
      firefox = mkBrowserOptions {
        browserName = "Firefox";
        defaultProfilePath = config.customConfig.user.name;
      };

      librewolf = mkBrowserOptions {
        browserName = "LibreWolf";
        defaultProfilePath = "rbb3lgdy.default";
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
