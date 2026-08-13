# ~/nixos-config/modules/nixos/common-options.nix
{ lib, pkgs, config /* config is the final NixOS config being built */, ... }:

# This top-level option group will hold all our custom configurations.
# We use 'customConfig' to avoid potential conflicts with existing NixOS 'config' attributes.
let
  
  colorMap = {
    "black" = "0;30"; "red" = "0;31"; "green" = "0;32"; "yellow" = "0;33";
    "blue" = "0;34"; "magenta" = "0;35"; "cyan" = "0;36"; "white" = "0;37";
    "bright-black" = "1;30"; "bright-red" = "1;31"; "bright-green" = "1;32";
    "bright-yellow" = "1;33"; "bright-blue" = "1;34"; "bright-magenta" = "1;35";
    "bright-cyan" = "1;36"; "bright-white" = "1;37";
  };

in
{
  options.customConfig = with lib; { # Define the 'customConfig' option set

    # -------------------------------------------------------------------------- #
    #                           USER AND SYSTEM BASICS                           #
    # -------------------------------------------------------------------------- #
    user = {
      name = mkOption {
        type = types.str;
        description = "The primary username for this host.";
        example = "landon";
      };
      email = mkOption {
        type = types.str;
        description = "The email for using git.";
        example = "example@gmail.com";
      };
      home = mkOption {
        type = types.str;
        # Default home directory path based on the username.
        default = "/home/${config.customConfig.user.name}"; # Accesses another option within customConfig
        defaultText = literalExpression ''"/home/''${config.customConfig.user.name}"'';
        description = "The absolute path to the primary user's home directory.";
      };
      shell = {
        bash = {
          enable = mkOption {
            type = types.bool;
            default = true; # Default to true if bash is the chosen shell
            description = "Whether to configure bash as the user's shell.";
          };
          color = mkOption {
            type = types.enum (attrNames colorMap);
            default = "green";
            description = "The color name for the bash prompt.";
            example = "blue";
          };
          pkg = mkOption {
            type = types.package;
            default = pkgs.bash; # Default to bash from pkgs
            description = "The shell package to use for the user.";
          };
        };
      };
      updateCmdPermission = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to allow the user to run the custom update/upgrade commands.";
      };
      sudoPassword = mkOption {
        type = types.bool;
        default = false;
        description = "Enable a separate, stronger password for sudo authentication, managed via a secondary password file.";
      };
      sopsPassword = mkOption {
        type = types.bool;
        default = false;
        description = "Manage user (and optionally root) password hashes via SOPS secrets instead of imperative chpasswd. Requires secrets/<hostname>.yaml to contain user-password-hash (and root-password-hash if sudoPassword is also enabled).";
      };
    };

    bootloader = {
      configurationLimit = mkOption {
        type = types.int;
        default = 10;
        description = "Maximum number of NixOS generations to keep in the boot menu. Lower for smaller /boot partitions.";
        example = 3;
      };
      quietBoot = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable quiet boot (suppress boot messages).";
      };
      plymouth = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Plymouth boot splash screen.";
        };
        theme = mkOption {
          type = types.str;
          default = "spinner";
          description = "Plymouth theme to use. Bundled options: spinner, bgrt, breeze, spinfinity.";
        };
      };
    };

    system = {
      hostName = mkOption {
        type = types.str;
        description = "The hostname for this system (e.g., 'optiplex', 'gaming-pc').";
        example = "my-nixos-pc";
      };
      stateVersion = mkOption {
        type = types.str;
        default = "24.11"; # Set your preferred default NixOS state version.
        description = "NixOS system state version from first install. DO NOT CHANGE EVEN AFTER SYSTEM UPGRADE.";
      };
      timeZone = mkOption {
        type = types.nullOr types.str;
        default = "America/Chicago"; # Example, choose your timezone
        description = "The system's timezone, e.g., 'Europe/Berlin', 'America/Los_Angeles'.";
        example = "UTC";
      };
      locale = mkOption {
        type = types.nullOr types.str;
        default = "en_US.UTF-8";
        description = "The system's primary locale.";
      };
      betaTesterHost = mkOption {
        type = types.bool;
        default = false;
        description = "When true, the sync command follows the latest open update/* branch instead of main.";
      };
    };

    networking = {
      networkmanager = {
        enable = mkOption {
          type = types.bool;
          default = true; # Default to true to use NetworkManager for most desktop setups
          description = "Whether to enable NetworkManager for handling network connections.";
        };
      };
      staticIP = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for static IP setups
          description = "Whether to configure a static IP address.";
        };
        interface = mkOption {
          type = types.nullOr types.str;
          default = null; # No default, must be set if staticIP.enable is true
          description = "The network interface to configure with a static IP (e.g., 'enp3s0', 'wlp2s0').";
        };
        address = mkOption {
          type = types.nullOr types.str;
          default = null; # No default, must be set if staticIP.enable is true
          description = "The static IPv4 address to assign (e.g., '192.168.1.100')";
        };
        gateway = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The gateway for the static IP configuration.";
        };
      };
      firewall = {
        enable = mkOption {
          type = types.bool;
          default = true; # Default to true to have basic firewall enabled
          description = "Whether to enable the NixOS firewall.";
        };
      };
      wakeOnLan = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Wake-on-LAN for the specified network interface.";
        };
        interface = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The network interface to enable Wake-on-LAN on (e.g., 'enp8s0').";
          example = "enp8s0";
        };
      };
      encryptedDns = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable encrypted DNS via dnscrypt-proxy2.";
        };
        resolver = mkOption {
          type = types.enum [ "cloudflare" "quad9" "mullvad" ];
          default = "cloudflare";
          description = "Which upstream DNS resolver to use. cloudflare = 1.1.1.1 (DoH), quad9 = filtered DoH, mullvad = privacy-focused DoH.";
        };
      };
      localDns = {
        server = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "IP of a local DNS server (e.g. optiplex-nas at 192.168.1.76) to use as the system resolver instead of upstream or dnscrypt-proxy. When set, dnscrypt-proxy is skipped and this IP is written to resolv.conf.";
          example = "192.168.1.76";
        };
      };
    };

    # Enables for specific system-level programs or services related to desktops
    # These are distinct from homeManagerModules which are user-level.
    programs = {
      partydeck = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for PartyDeck
          description = "Enable PartyDeck, a splitscreen gaming application for KDE.";
        };
      };
      firefox = {
        enable = lib.mkEnableOption "Enable Firefox/Librewolf configuration via Home Manager.";

        package = lib.mkOption {
          type = with lib.types; package;
          default = pkgs.firefox;
          defaultText = "pkgs.firefox";
          description = "The package to use for the Firefox configuration (e.g., pkgs.librewolf or pkgs.firefox).";
        };

        extensions = lib.mkOption {
          type = with lib.types; listOf package;
          default = [];
          description = "List of Firefox extensions to install.";
          example = ''
            with pkgs.nur.repos.rycee.firefox-addons; [
              ublock-origin
              privacy-badger
            ];
          '';
        };

        bookmarks = lib.mkOption {
          # The actual type is very complex, so 'anything' is sufficient here
          # since the firefox module itself will validate the structure.
          type = with lib.types; anything;
          default = [];
          description = "A declarative list of bookmarks and folders to configure.";
          example = ''
            [
              {
                name = "NixOS Search";
                url = "https://search.nixos.org/";
                keyword = "nix";
              }
              "separator"
              {
                name = "Reading List";
                toolbar = true; # Add this folder to the bookmarks toolbar
                bookmarks = [
                  { name = "Some Blog"; url = "https://example.com"; }
                ];
              }
            ]
          '';
        };
      };
      flatpak = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for Flatpak support
          description = "Enable Flatpak packages for Spotify and Discord.";
        };
      };
    };

    # -------------------------------------------------------------------------- #
    #                                HOME MANAGER                                #
    # -------------------------------------------------------------------------- #
    homeManager = {
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

    # -------------------------------------------------------------------------- #
    #                            PACKAGES & APPLICATIONS                         #
    # -------------------------------------------------------------------------- #
    packages = {
      nixos = mkOption { # System-wide packages
        type = with types; listOf package;
        default = [];
        description = "List of additional system-wide packages to install via NixOS configuration.";
        example = "with pkgs; [ htop vim ]"; # For documentation
      };
      unstable-override = mkOption {
        type = with types; listOf str;
        default = [];
        description = "List of package attribute names to pull from the unstable channel.";
        example = ''[ "discord-canary" "obs-studio" "vscode" ]'';
      };
      homeManager = mkOption { # User-specific packages
        type = with types; listOf package;
        default = [];
        description = "List of additional user-specific packages to install via Home Manager.";
        example = "with pkgs; [ cowsay neofetch ]";
      };
      flatpak = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for Flatpak support
          description = "Enable Flatpak packages for Spotify and Discord.";
        };
        packages = mkOption {
          type = with lib.types; listOf str;
          default = [];
          description = "List of Flatpak packages to install if flatpak is enabled.";
          example = "[ { appId = \"com.brave.Browser\"; origin = \"flathub\"; }
            \"com.obsproject.Studio\"
            \"im.riot.Riot\"
            \"com.spotify.Client\"
            \"com.discordapp.Discord\" 
          ]";
        };
      };
    };

    # -------------------------------------------------------------------------- #
    #                             PROFILES / USE CASES                           #
    # -------------------------------------------------------------------------- #
    profiles = {
      gaming = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for gaming PCs
          description = "Enable a comprehensive set of configurations and programs for an optimal gaming experience.";
        };
      };
      development = {
        fpga-ice40 = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for FPGA development
            description = "Enable FPGA development tools and configurations for ice40 series.";
          };
        };
        kernel = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for kernel development
            description = "Enable Linux kernel development tools and configurations.";
          };
        };
        embedded-linux = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable embedded Linux development tools and cross-compilers.";
          };
        };
        gbdk = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Game Boy development tools and the GBDK dev shell.";
          };
        };
        cpp-practice = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable C++ practice dev environment with compiler and build tools.";
          };
        };
      };
      # You could add other profiles like 'development', 'server', 'htpc' here later
    };

    # -------------------------------------------------------------------------- #
    #                             PROGRAMS                                       #
    # -------------------------------------------------------------------------- #
    programs = {
      claudeCode = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable claude-code with uv (for uvx) and mcp-nixos MCP server.";
        };
        extraChownPaths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "/home/lando/hyprland-keys" ];
          description = ''
            Extra directories the Claude hooks chown back to the primary user after
            edits. The user's nixos-config clone is always included; list additional
            working clones here.
          '';
        };
      };
    };

    # -------------------------------------------------------------------------- #
    #                        NIX & SYSTEM OPTIMIZATIONS                          #
    # -------------------------------------------------------------------------- #

  }; # End of customConfig option set
  
}