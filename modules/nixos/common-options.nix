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

  # Builds one entry of customConfig.apps.programs.<role>.
  #
  # Each user application is declared once, as a package plus the command used to
  # launch it, and the command is *derived* from the package. That linkage is the
  # whole point: setting `package = null` both drops the install and empties the
  # command, so no store path is left dangling in a keybind (an interpolated
  # "${pkgs.foo}/bin/foo" default pulls foo into the closure even when foo is not
  # in home.packages — the trap that made removing librewolf so awkward).
  #
  # `exe` is given explicitly rather than using lib.getExe because several
  # packages' binary names differ from their attribute name (bitwarden-desktop ->
  # bitwarden, vscode -> code, btop-rocm -> btop, neovim -> nvim) and
  # meta.mainProgram is not reliably set for all of them.
  mkAppRole =
    { package ? null
    , exe ? null
    , args ? ""
    , command ? null   # for roles installed elsewhere (e.g. the gaming profile)
    , description
    }:
    lib.mkOption {
      inherit description;
      default = {};
      type = lib.types.submodule ({ config, ... }: {
        options = {
          package = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = package;
            description = "Package to install for this role. null means do not install it.";
          };
          exe = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = exe;
            description = ''
              Name of the binary inside `package`, used to derive `command`.
              Override this alongside `package` when swapping in an application
              whose binary is named differently (e.g. vesktop for the chat role).
            '';
          };
          args = lib.mkOption {
            type = lib.types.str;
            default = args;
            description = "Arguments appended to the derived `command`.";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = ''
              Command used to launch this application. Derived from `package` and
              `exe` by default. An empty string means the role is unset: no
              keybind is emitted for it.
            '';
          };
        };
        # mkDefault so a host can override the command on its own (e.g. to launch
        # a Flatpak) without having to restate the package.
        config.command = lib.mkDefault (
          if config.package == null then (if command != null then command else "")
          else "${config.package}/bin/${config.exe}${config.args}"
        );
      });
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

    # -------------------------------------------------------------------------- #
    #                       DESKTOP ENVIRONMENT & COMPONENTS                     #
    # -------------------------------------------------------------------------- #
    desktop = {
      enable = mkOption {
          type = types.bool;
          default = true; # Usually true if a graphical environment is selected, can be overridden
          # Consider defaulting based on desktop.environment != "none"
          # default = (config.customConfig.desktop.environment != "none");
          description = "Whether to enable a desktop environment.";
        };
      environments = mkOption {
        type = types.listOf (types.enum [ "hyprland" "cosmic" "kde" "xfce" "none" ]);
        default = []; # Default to an empty list
        example = [ "kde" "hyprland" ];
        description = "A list of desktop environments or window managers to make available on the system.";
      };
      kde = {
        kwallet = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable KWallet for credential storage. Required for plasma-nm to persist WiFi passwords across sessions. Pairs with SDDM PAM auto-unlock so no wallet password prompt appears at login.";
          };
        };
      };
      monitors = mkOption {
        type = with types; listOf (submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "A descriptive name for this monitor configuration.";
              example = "main";
            };
            identifier = mkOption {
              type = types.str;
              description = "The monitor identifier. Can be a manufacturer description (desc:...) or output name (DP-1, HDMI-A-1, etc.).";
              example = "Dell Inc. DELL S2721HGF DZR2123";
            };
            edid = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Optional EDID description substring (make / model / serial) used ONLY by the
                XFCE X11 monitor resolver to identify this monitor stably regardless of
                connector-name reordering. Hyprland ignores this and matches on `identifier`.
                Needed because X11 (NVIDIA) and Wayland report DIFFERENT connector names for
                the same physical port (e.g. an output that is DP-1 under Wayland is DP-0 under
                X11), so a shared connector name can't drive both sessions. When null, the XFCE
                resolver falls back to `identifier`.
              '';
              example = "LG ULTRAGEAR";
            };
            wallpaper = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Optional per-monitor wallpaper image. Used by the XFCE windows7 wallpaper script
                to override this monitor's orientation default (portrait → vertical image,
                landscape → Win7 image) — e.g. to mirror the per-monitor wallpapers the Hyprland
                theme shows on the same host. null = use the orientation default.
              '';
              example = literalExpression "../../assets/wallpapers/f-15-satellite.jpg";
            };
            resolution = mkOption {
              type = types.str;
              default = "preferred";
              description = "Monitor resolution and refresh rate.";
              example = "1920x1080@144";
            };
            position = mkOption {
              type = types.str;
              default = "0x0";
              description = "Monitor position in pixels (x,y).";
              example = "1920x0";
            };
            scale = mkOption {
              type = types.str;
              default = "1";
              description = "Monitor scaling factor.";
              example = "1.5";
            };
            transform = mkOption {
              type = types.nullOr (types.enum [ "0" "1" "2" "3" ]);
              default = null;
              description = "Monitor rotation: 0=normal, 1=90°, 2=180°, 3=270°.";
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether this monitor configuration is enabled.";
            };
          };
        });
        default = [];
        description = "List of monitor configurations for Hyprland.";
        example = literalExpression ''
          [
            {
              name = "main";
              identifier = "Dell Inc. DELL S2721HGF DZR2123";
              resolution = "1920x1080@144";
              position = "0x0";
              scale = "1";
            }
            {
              name = "secondary";
              identifier = "DP-2";
              resolution = "1920x1080@60";
              position = "1920x0";
              scale = "1";
            }
          ]
        '';
      };
      autostart = mkOption {
        type = types.listOf (types.submodule {
          options = {
            command = mkOption {
              type = types.str;
              description = "Command to run on startup.";
              example = "discord";
            };
            desktops = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Desktop environments to autostart on. Empty list means all enabled DEs.";
              example = [ "hyprland" "kde" ];
            };
            workspace = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Hyprland workspace number to open the app on silently. Null means no preference.";
              example = 2;
            };
            windowClass = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Hyprland window class for workspace assignment via windowrulev2 (more reliable than exec-once prefix for XWayland apps). Use hyprctl clients to find the class.";
              example = "discord";
            };
          };
        });
        default = [];
        description = ''
          Applications to autostart at login. Each entry specifies a command and
          optionally which desktop environments should start it. An empty `desktops`
          list means start on all enabled DEs.
        '';
      };
      idle = {
        screensaverTimeout = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Seconds of idle before the screensaver activates (AC power). Currently consumed
            by XFCE (xfce4-screensaver); locking then follows at idle.lockTimeout. Null =
            no separate screensaver stage (saver == lock).
          '';
          example = 900;
        };
        lockTimeout = mkOption {
          type = types.nullOr types.int;
          default = 600;
          description = "Seconds of idle before the screen locks (AC power). Set to null to disable auto-lock.";
          example = 900;
        };
        sleepTimeout = mkOption {
          type = types.nullOr types.int;
          default = 1800;
          description = "Seconds of idle before the display turns off (AC power). Set to null to disable.";
          example = 3600;
        };
        battery = {
          lockTimeout = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Seconds of idle before the screen locks on battery. Null falls back to idle.lockTimeout.";
            example = 600;
          };
          sleepTimeout = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Seconds of idle before the display turns off on battery. Null falls back to idle.sleepTimeout.";
            example = 900;
          };
        };
      };
      wayvnc = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable wayvnc VNC server for Hyprland.";
        };
        targetMonitor = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Name of the monitor to use for wayvnc. Corresponds to monitor.name in desktop.monitors.";
          example = "tv";
        };
      };
      xrdp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable the xrdp remote-desktop server so a desktop session (e.g. XFCE) can be reached over RDP. Keep openFirewall off and tunnel over SSH for a private setup.";
        };
        windowManager = mkOption {
          type = types.str;
          default = "startxfce4";
          description = ''
            Session command xrdp launches for each remote login. Use the DE's session
            *launcher* (e.g. "startxfce4", "gnome-session"), not the bare session binary —
            launchers set up the D-Bus session bus and XDG_* env that xrdp doesn't provide,
            without which the session exits immediately on login.
          '';
        };
        openFirewall = mkOption {
          type = types.bool;
          default = false;
          description = "Open TCP 3389 on the firewall. Leave false to require an SSH tunnel (ssh -L 3389:localhost:3389).";
        };
      };
      hyprland = {
        launcher = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable the Hyprland launcher bar (typically at bottom center).";
          };
          pinnedApps = mkOption {
            type = with types; listOf (submodule {
              options = {
                label = mkOption {
                  type = types.str;
                  description = "Display label for the launcher button (e.g., 'TERM', 'NAV', 'CODE').";
                  example = "TERM";
                };
                command = mkOption {
                  type = types.str;
                  description = "Command to execute when the launcher button is clicked.";
                  example = "\${pkgs.kitty}/bin/kitty";
                };
                tooltip = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Optional tooltip text for the launcher button.";
                  example = "Launch Terminal";
                };
              };
            });
            default = [];
            description = "List of pinned applications for the launcher bar.";
            example = literalExpression ''
              [
                {
                  label = "TERM";
                  command = "\${pkgs.kitty}/bin/kitty";
                  tooltip = "Terminal";
                }
                {
                  label = "FILES";
                  command = "\${pkgs.cosmic-files}/bin/cosmic-files";
                  tooltip = "File Manager";
                }
              ]
            '';
          };
        };
        drmDevice = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Explicit DRM device path for Hyprland (AQ_DRM_DEVICES). Set this on hosts with
            multiple GPUs (e.g. NVIDIA + AMD iGPU) to pin Hyprland to the correct card.
            Use the stable by-path link: /dev/dri/by-path/pci-<BBBB:DD:FF.f>-card.
            Find your GPU PCI address with: ls -la /dev/dri/by-path/
          '';
          example = "/dev/dri/by-path/pci-0000:01:00.0-card";
        };

        utilityApps = mkOption {
          type = types.listOf (types.submodule {
            options = {
              command = mkOption {
                type = types.str;
                description = "Command to launch the app.";
                example = "ckb-next";
              };
              windowClass = mkOption {
                type = types.str;
                description = "Hyprland window class for the window rule (use hyprctl clients to find).";
                example = "ckb-next";
              };
            };
          });
          default = [];
          description = ''
            Applications to autostart silently into the special utility workspace (special:ckb).
            A windowrulev2 sends each app there on launch; SUPER+` toggles the workspace.
          '';
        };
        weather = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to show a weather widget in the waybar.";
          };
          location = mkOption {
            type = types.str;
            default = "";
            description = "Location for weather lookup (e.g. 'Austin' or 'New York'). Empty string auto-detects by IP.";
            example = "Austin, TX";
          };
          useFahrenheit = mkOption {
            type = types.bool;
            default = true;
            description = "Show temperature in Fahrenheit. Set false for Celsius.";
          };
        };
        audioSinkMappings = mkOption {
          type = types.listOf (types.submodule {
            options = {
              match = mkOption {
                type = types.str;
                description = "Substring to match against the sink description (as shown in pavucontrol Output Devices tab).";
              };
              icon = mkOption {
                type = types.str;
                description = "Nerd Font glyph for this device type (e.g. speaker 󰕾 U+F057E, headphones 󰋋 U+F040B).";
              };
              class = mkOption {
                type = types.str;
                default = "default";
                description = "CSS class applied to the waybar widget when this sink is active (e.g. speakers, headphones).";
              };
              label = mkOption {
                type = types.str;
                default = "";
                description = "Short text label shown alongside the sink name in the rofi sink-switcher menu.";
              };
            };
          });
          default = [];
          description = ''
            Map audio sink description substrings to Nerd Font icons for the waybar audio indicator
            and the rofi sink-switcher menu. Useful on hosts where HDMI audio outputs are ambiguous
            (e.g. an HDMI port feeding a monitor whose audio-out jack connects to headphones).
            Patterns are matched as substrings against the sink description from pactl.
          '';
          example = [
            { match = "Pro 7"; icon = "󰕾"; class = "speakers"; label = "SPKR"; }
            { match = "Pro 8"; icon = "󰋋"; class = "headphones"; label = "HDPH"; }
          ];
        };
      };
      kde = {
        terminalApp = mkOption {
          type = types.str;
          default = "org.kde.konsole";
          description = ''
            Desktop file ID of the terminal emulator to bind to Meta+Return in KDE.
            Use the application ID without the .desktop extension
            (e.g. "org.kde.konsole", "com.raggesilver.BlackBox").
          '';
          example = "com.raggesilver.BlackBox";
        };
      };
      displayManager = {
        enable = mkOption {
          type = types.bool;
          default = true; # Usually true if a graphical environment is selected, can be overridden
          # Consider defaulting based on desktop.environment != "none"
          # default = (config.customConfig.desktop.environment != "none");
          description = "Whether to enable a display manager.";
        };
        type = mkOption {
          type = types.enum [ "sddm" "cosmic" "gdm" "greetd" "ly" "none" ]; # Add more as needed
          default = "sddm"; # A common default, adjust as preferred
          description = "Which display manager to use if displayManager.enable is true. 'none' means no DM managed by this option.";
        };
        sddm = {
          theme = mkOption {
            type = types.str;
            default = "none";
            description = "The SDDM theme to use (e.g., 'sddm-astronaut', 'sddm-windows7').";
          };
          embeddedTheme = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "The embedded theme for sddm-astronaut (e.g., 'pixel_sakura').";
          };
          screensaver = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to use the SDDM theme as a screensaver after a timeout.";
            };
            timeout = mkOption {
              type = types.int;
              default = 15;
              description = "The idle time in minutes before the SDDM screensaver starts.";
            };
          };
          customTheme = {
            enable = mkEnableOption "a custom embedded theme for sddm-astronaut";

            wallpaper = mkOption {
              type = types.path;
              description = "Absolute path to the wallpaper for the custom SDDM theme.";
              example = "/path/to/my/wallpaper.png";
            };

            font = mkOption {
              type = types.str;
              default = "Thunderman";
              description = "The font to use in the theme.";
            };

            fontSize = mkOption {
              type = types.int;
              default = 12;
              description = "The base font size.";
            };

            blur = mkOption {
              type = types.float;
              default = 2.0;
              description = "The blur intensity for the form background.";
            };

            roundCorners = mkOption {
              type = types.int;
              default = 20;
              description = "The roundness of corners.";
            };

            colors = mkOption {
              type = with types; submodule {
                options = {
                  headerText = mkOption { type = types.str; default = "#d8d8ff"; };
                  dateText = mkOption { type = types.str; default = "#d8d8ff"; };
                  timeText = mkOption { type = types.str; default = "#d8d8ff"; };
                  formBackground = mkOption { type = types.str; default = "#242455"; };
                  dimBackground = mkOption { type = types.str; default = "#242455"; };
                  loginButtonText = mkOption { type = types.str; default = "#6c6caa"; };
                  loginButtonBackground = mkOption { type = types.str; default = "#d8d8ff"; };
                  systemButtonsIcons = mkOption { type = types.str; default = "#d8d8ff"; };
                  placeholderText = mkOption { type = types.str; default = "#6c6caa"; };
                  highlightBackground = mkOption { type = types.str; default = "#d8d8ff"; };
                };
              };
              default = {};
              description = "Color palette for the custom SDDM theme. All values should be hex color codes.";
            };
          };
        };
        ly = {
          theme = mkOption {
            type = types.str;
            default = "none";
            description = "The Ly theme to apply. 'none' uses Ly defaults. Available themes: 'doom', 'matrix', 'century-series'.";
          };
          animationFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Override the .dur animation file used by the century-series theme. Null uses the default 320x90 file (suited for 2560x1440). Set to a host-specific file for different resolutions.";
          };
          ttyRows = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            description = "TTY row count to pass to stty before Ly starts. When set (together with ttyCols), enables NVIDIA fbdev kernel params and a pre-start systemd service that sizes tty1 correctly so Ly and its animation fill the screen.";
          };
          ttyCols = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            description = "TTY column count to pass to stty before Ly starts.";
          };
          nativeFbResolution = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                width  = mkOption { type = types.ints.positive; description = "Native framebuffer width in pixels."; };
                height = mkOption { type = types.ints.positive; description = "Native framebuffer height in pixels."; };
              };
            });
            default = null;
            description = "When set, fbset resets the framebuffer to this resolution before stty. Only needed when Plymouth leaves the framebuffer at a different resolution than native (e.g. 2560x1440 displays where EFI GOP uses 1920x1080).";
          };
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

    apps = {
      # ------------------------------------------------------------------------ #
      # User applications
      #
      # The set of user-facing programs a machine installs. These used to be
      # hardcoded in modules/home-manager/hyprland/functional.nix, which made the
      # app set invisible from the host file and impossible to override. Desktop
      # *environment* infrastructure (waybar, rofi, hyprsunset, swaylock, fonts,
      # portals) still belongs to the Hyprland module — only user applications
      # live here.
      #
      # The defaults reproduce the full "complete DE" experience, so a host that
      # says nothing gets everything. To drop an app, set its package to null:
      #
      #   apps.programs.browser = {
      #     package = null;                                 # not installed
      #     command = "flatpak run org.chromium.Chromium";  # keybind still works
      #   };
      #
      # Leaving `command` unset alongside `package = null` also removes the
      # application's Hyprland keybind.
      # ------------------------------------------------------------------------ #
      programs = {
        enable = mkOption {
          type = types.bool;
          default = lib.elem "hyprland" config.customConfig.desktop.environments;
          defaultText = literalExpression ''lib.elem "hyprland" config.customConfig.desktop.environments'';
          description = ''
            Install the customConfig user application set. Defaults to enabled on
            Hyprland hosts, which is where this set was previously hardcoded;
            KDE-only hosts opt in explicitly.
          '';
        };

        # ── Browsers ──────────────────────────────────────────────────────────
        browser = mkAppRole {
          package = pkgs.librewolf; exe = "librewolf";
          description = "Primary web browser (Super+B).";
        };
        browserAlt = mkAppRole {
          package = pkgs.brave; exe = "brave";
          description = "Alternative web browser (Super+Alt+B).";
        };

        # ── Terminal and file management ──────────────────────────────────────
        terminal = mkAppRole {
          package = pkgs.kitty; exe = "kitty";
          description = "Terminal emulator; backs the \$terminal Hyprland variable (Super+Return).";
        };
        fileManager = mkAppRole {
          package = pkgs.kdePackages.dolphin; exe = "dolphin";
          description = "Graphical file manager; backs the \$fileManager Hyprland variable (Super+Alt+F).";
        };
        fileManagerTUI = mkAppRole {
          package = pkgs.yazi; exe = "yazi";
          description = "Terminal file manager (Super+F, opened inside \$terminal).";
        };

        # ── Editors ───────────────────────────────────────────────────────────
        editor = mkAppRole {
          package = pkgs.kdePackages.kate; exe = "kate";
          description = "Graphical text editor (Super+T).";
        };
        editorTUI = mkAppRole {
          package = pkgs.neovim; exe = "nvim";
          description = "Terminal text editor; backs the nvim-kitty.desktop MIME wrapper.";
        };
        ide = mkAppRole {
          package = pkgs.vscode; exe = "code";
          description = "IDE / code editor (Super+I).";
        };

        # ── System ────────────────────────────────────────────────────────────
        taskManager = mkAppRole {
          package = pkgs.btop-rocm; exe = "btop";
          description = "Task manager (Ctrl+Shift+Escape, opened inside \$terminal).";
        };
        passwordManager = mkAppRole {
          package = pkgs.bitwarden-desktop; exe = "bitwarden";
          description = "Password manager (Super+P).";
        };

        # ── Communication ─────────────────────────────────────────────────────
        chat = mkAppRole {
          package = pkgs.discord; exe = "discord";
          description = "Primary chat application (Super+C).";
        };
        chatAlt = mkAppRole {
          package = pkgs.signal-desktop; exe = "signal-desktop";
          description = "Alternative chat application (Super+Alt+C).";
        };

        # ── Media ─────────────────────────────────────────────────────────────
        music = mkAppRole {
          package = pkgs.spotify; exe = "spotify";
          args = " --enable-features=UseOzonePlatform --ozone-platform=wayland";
          description = "Music player (Super+M).";
        };
        audioVisualizer = mkAppRole {
          package = pkgs.cava; exe = "cava";
          description = "Audio visualizer (Super+Alt+M, opened inside \$terminal).";
        };
        videoPlayer = mkAppRole {
          package = pkgs.mpv; exe = "mpv";
          description = "Video and audio player; the MIME default for video/* and audio/*.";
        };
        imageViewer = mkAppRole {
          package = pkgs.imv; exe = "imv";
          description = "Image viewer; the MIME default for image/*.";
        };
        pdfReader = mkAppRole {
          package = pkgs.zathura; exe = "zathura";
          description = "PDF reader; the MIME default for application/pdf.";
        };
        archiveManager = mkAppRole {
          package = pkgs.file-roller; exe = "file-roller";
          description = "Archive manager; the MIME default for archive types.";
        };

        # ── Gaming ────────────────────────────────────────────────────────────
        # Installed by customConfig.profiles.gaming (a profile, not an app set),
        # so these carry no package and resolve from PATH.
        gaming = mkAppRole {
          command = "steam";
          description = "Primary gaming platform (Super+G). Installed by the gaming profile.";
        };
        gamingAlt = mkAppRole {
          command = "lutris";
          description = "Alternative gaming platform (Super+Alt+G). Installed by the gaming profile.";
        };
      };

      # Selects which DE's default app preset feeds into xdg.mimeApps.
      # "hyprland" = TUI-first defaults (yazi, neovim, imv, zathura, mpv).
      # "kde"      = GUI-native defaults (dolphin, kate, gwenview, okular, ark).
      # Individual apps within each set can be overridden per-host via
      # apps.defaults.<set>.<app> = "something.desktop".
      defaultSet = mkOption {
        type = types.enum [ "hyprland" "kde" ];
        default = "hyprland";
        description = ''
          Which desktop environment's default app preset to use for XDG MIME
          associations. Set to "kde" for KDE-primary hosts.
        '';
      };

      # Desktop file names for XDG MIME default application associations.
      # These are used in xdg.mimeApps.defaultApplications (e.g. "librewolf.desktop").
      # Separate from customConfig.desktop.hyprland.applications.* which hold launch commands for keybinds.
      defaults = {

        hyprland = {
          browser = mkOption {
            type = types.str;
            default = "librewolf.desktop";
            description = "Default browser for Hyprland hosts.";
            example = "firefox.desktop";
          };
          terminal = mkOption {
            type = types.str;
            default = "kitty.desktop";
            description = "Default terminal for Hyprland hosts.";
          };
          fileManager = mkOption {
            type = types.str;
            default = "yazi-kitty.desktop";
            description = "Default file manager for Hyprland hosts (TUI wrapper).";
            example = "org.kde.dolphin.desktop";
          };
          textEditor = mkOption {
            type = types.str;
            default = "nvim-kitty.desktop";
            description = "Default text editor for Hyprland hosts (TUI wrapper).";
            example = "org.kde.kate.desktop";
          };
          codeEditor = mkOption {
            type = types.str;
            default = "code.desktop";
            description = "Default code editor for Hyprland hosts.";
          };
          imageViewer = mkOption {
            type = types.str;
            default = "imv.desktop";
            description = "Default image viewer for Hyprland hosts.";
          };
          videoPlayer = mkOption {
            type = types.str;
            default = "mpv.desktop";
            description = "Default video player for Hyprland hosts.";
          };
          audioPlayer = mkOption {
            type = types.str;
            default = "mpv.desktop";
            description = "Default audio player for Hyprland hosts.";
          };
          pdfReader = mkOption {
            type = types.str;
            default = "org.pwmt.zathura.desktop";
            description = "Default PDF reader for Hyprland hosts.";
            example = "okular.desktop";
          };
          archiveManager = mkOption {
            type = types.str;
            default = "org.gnome.FileRoller.desktop";
            description = "Default archive manager for Hyprland hosts.";
            example = "ark.desktop";
          };
          emailClient = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default email client for Hyprland hosts. null disables mailto association.";
            example = "thunderbird.desktop";
          };
          torrentClient = mkOption {
            type = types.str;
            default = "org.qbittorrent.qBittorrent.desktop";
            description = "Default torrent client for Hyprland hosts.";
          };
        };

        kde = {
          browser = mkOption {
            type = types.str;
            default = "librewolf.desktop";
            description = "Default browser for KDE hosts.";
            example = "firefox.desktop";
          };
          terminal = mkOption {
            type = types.str;
            default = "org.kde.konsole.desktop";
            description = "Default terminal for KDE hosts.";
          };
          fileManager = mkOption {
            type = types.str;
            default = "org.kde.dolphin.desktop";
            description = "Default file manager for KDE hosts.";
          };
          textEditor = mkOption {
            type = types.str;
            default = "org.kde.kate.desktop";
            description = "Default text editor for KDE hosts.";
          };
          codeEditor = mkOption {
            type = types.str;
            default = "code.desktop";
            description = "Default code editor for KDE hosts.";
          };
          imageViewer = mkOption {
            type = types.str;
            default = "org.kde.gwenview.desktop";
            description = "Default image viewer for KDE hosts.";
          };
          videoPlayer = mkOption {
            type = types.str;
            default = "mpv.desktop";
            description = "Default video player for KDE hosts.";
            example = "vlc.desktop";
          };
          audioPlayer = mkOption {
            type = types.str;
            default = "mpv.desktop";
            description = "Default audio player for KDE hosts.";
            example = "vlc.desktop";
          };
          pdfReader = mkOption {
            type = types.str;
            default = "okularApplication_pdf.desktop";
            description = "Default PDF reader for KDE hosts.";
          };
          archiveManager = mkOption {
            type = types.str;
            default = "ark.desktop";
            description = "Default archive manager for KDE hosts.";
          };
          emailClient = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Default email client for KDE hosts. null disables mailto association.";
            example = "thunderbird.desktop";
          };
          torrentClient = mkOption {
            type = types.str;
            default = "org.qbittorrent.qBittorrent.desktop";
            description = "Default torrent client for KDE hosts.";
          };
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
    #                             HARDWARE AND PERIPHERALS                       #
    # -------------------------------------------------------------------------- #
    hardware = {
      unstable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to source the entire hardware stack (kernel, initrd modules, etc.) from nixpkgs-unstable.";
      };

      monitors = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Output connector name (e.g., DP-1, HDMI-A-1). Must match the kernel connector name.";
              example = "DP-4";
            };
            width = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Horizontal resolution in pixels. null = preferred mode.";
            };
            height = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Vertical resolution in pixels. null = preferred mode.";
            };
            refreshRate = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Refresh rate in Hz. null = preferred mode.";
            };
            x = mkOption {
              type = types.int;
              default = 0;
              description = "Horizontal position in the virtual display space (pixels from left).";
            };
            y = mkOption {
              type = types.int;
              default = 0;
              description = "Vertical position in the virtual display space (pixels from top).";
            };
            rotation = mkOption {
              type = types.enum [ "Normal" "Rotated90" "Rotated180" "Rotated270" ];
              default = "Normal";
              description = "Display rotation. Rotated90 = 90° clockwise (use for portrait monitors physically rotated CCW).";
            };
            scale = mkOption {
              type = types.float;
              default = 1.0;
              description = "Display scale factor (e.g., 1.25 for 125% scaling).";
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
              description = "Whether this output is active.";
            };
          };
        });
        default = [];
        description = ''
          Declarative monitor configuration. Currently used by SDDM (KWin) for rotation and scale.
          Hyprland and KDE support will be added in future tasks.
          Connector names can be found via: cat ~/.config/kwinoutputconfig.json
        '';
      };
      nvidia = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly on NVIDIA machines
            description = "Enable NVIDIA drivers and related configuration.";
          };
          package = mkOption {
            type = types.enum [ "latest" "production" "stable" "legacy_535" "legacy_470" "legacy_390" ];
            default = "latest";
            description = ''
              Which NVIDIA driver package to use. Options:
              - "latest" - Latest driver (may drop support for older GPUs)
              - "production" - Production branch driver
              - "stable" - Stable branch (580.xx series, supports GTX 1000 series)
              - "legacy_535" - Legacy 535.xx branch
              - "legacy_470" - Legacy 470.xx branch (for Kepler GPUs)
              - "legacy_390" - Legacy 390.xx branch (for older GPUs)
            '';
          };
        laptop = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable dual GPU and PRIME for Nvidia laptops.";
          };
          nvidiaID = mkOption {
            type = types.nullOr types.str;
            default = null; # Default to empty, can be set to specific GPU ID if needed
            description = "The NVIDIA GPU ID for PRIME configurations on laptops.";
          };
          intelBusID = mkOption {
            type = types.nullOr types.str;
            default = null; # Default to empty, can be set to specific GPU ID if needed
            description = "The Intel GPU ID for PRIME configurations on laptops.";
          };
          amdgpuID = mkOption {
            type = types.nullOr types.str;
            default = null; # Default to empty, can be set to specific GPU ID if needed
            description = "The AMD GPU ID for PRIME configurations on laptops.";
          };
        };
        # You could add more nvidia options here: powerManagement, openDrivers, etc.
      };
      peripherals = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for peripheral configurations
          description = "Enable configurations for hardware peripherals like keyboards, mice, etc.";
        };
        openrgb = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for OpenRGB support
            description = "Enable OpenRGB for RGB lighting control.";
          };
        };
        openrazer = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for Razer device support
            description = "Enable OpenRazer for Razer device support.";
          };
        };
        ckb-next = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable ckb-next for Corsair device support.";
          };
          # Color and brightness are managed at runtime via ~/.cache/ckb-color-state
          # and cycled through the century-series waybar widget / keybinds.
        };
        input-remapper = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable input-remapper for key/mouse remapping.";
          };
        };
        solaar = {
           enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable Solaar for Logitech device management.";
           };
        };
        asus = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable ASUS laptop specific services and tools (asusctl).";
          };
        };
      };
      display = {
        backlight = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable screen backlight control (brightnessctl). Shows brightness widget in Waybar.";
          };
        };
      };
      kbdBacklight = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable keyboard backlight control via brightnessctl. Shows kbd brightness widget in Waybar.";
        };
      };
      battery = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable battery status widget in Waybar. Enable for laptops with a battery.";
        };
      };
      bluetooth = {
        waybar = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Show Bluetooth status widget in Waybar. Enable for hosts that use Bluetooth devices.";
          };
        };
      };
      touchpad = {
        naturalScroll = mkOption {
          type = types.bool;
          default = true;
          description = "Enable natural (macOS-style) scrolling for touchpad. Content follows finger direction. Applied to Hyprland and KDE.";
        };
      };
    };

    # -------------------------------------------------------------------------- #
    #                             SERVICES (NixOS Level)                         #
    # -------------------------------------------------------------------------- #
    services = {
      ssh = {
        enable = mkOption { 
          type = types.bool; 
          default = false; 
          description = "Enable OpenSSH server."; 
        };
        # port = mkOption { type = types.port; default = 22; };
      };
      vscodeServer = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable vscode server.";
        };
        # port = mkOption { type = types.port; default = 22; };
      };
      wireguard = {
        server = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable the WireGuard server host configuration.";
          };
          
          interfaceName = mkOption {
            type = types.str;
            default = "wg0";
            description = "The name of the WireGuard network interface.";
          };

          address = mkOption {
            type = types.str;
            example = "10.100.100.1/24";
            description = "The IP address and subnet for the WireGuard server itself.";
          };

          listenPort = mkOption {
            type = types.port;
            default = 51820;
            description = "The UDP port on which the WireGuard server will listen.";
          };

          privateKeyFile = mkOption {
            type = types.path;
            description = "Absolute path to the file containing the server's private key.";
            example = "/etc/nixos/secrets/wireguard/private";
          };

          peers = mkOption {
            type = with types; listOf (submodule {
              options = {
                publicKey = mkOption {
                  type = types.str;
                  description = "The public key of the peer.";
                };
                allowedIPs = mkOption {
                  type = with types; listOf str;
                  description = "List of IP addresses this peer is allowed to use within the tunnel.";
                  example = [ "10.100.100.2/32" ];
                };
                presharedKeyFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Optional: Absolute path to a pre-shared key for this peer for extra security.";
                };
              };
            });
            default = [];
            description = "A list of peers (clients) that are allowed to connect to this server.";
          };
        };
        client = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable the WireGuard client configuration.";
          };

          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to automatically start the WireGuard client on boot.";
          };

          interfaceName = mkOption {
            type = types.str;
            default = "wg0";
            description = "The name of the WireGuard network interface.";
          };

          address = mkOption {
            type = types.str;
            example = "10.10.0.3/32";
            description = "The IP address for this client within the tunnel.";
          };

          dns = mkOption {
            type = with types; listOf str;
            default = [];
            description = "DNS servers to use when the tunnel is active.";
          };

          privateKeyFile = mkOption {
            type = types.path;
            description = "Absolute path to the file containing the client's private key.";
          };

          peer = {
            publicKey = mkOption {
              type = types.str;
              description = "The public key of the WireGuard server.";
            };
            allowedIPs = mkOption {
              type = with types; listOf str;
              default = [ "0.0.0.0/0" ];
              description = "IP ranges to route through the tunnel.";
            };
            endpoint = mkOption {
              type = types.str;
              description = "The server endpoint as host:port.";
            };
            persistentKeepalive = mkOption {
              type = types.int;
              default = 25;
              description = "Keepalive interval in seconds (0 to disable).";
            };
          };
        };
      };

      autoUpdate = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable weekly automated git sync + nixos-rebuild on this host.";
        };
        day = mkOption {
          type = types.enum [ "Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun" ];
          default = "Mon";
          description = "Day of the week to run (systemd OnCalendar weekday).";
          example = "Sun";
        };
        time = mkOption {
          type = types.str;
          default = "03:00";
          description = "Time of day in HH:MM 24-hour format.";
          example = "04:30";
        };
        randomizedDelaySec = mkOption {
          type = types.str;
          default = "30min";
          description = "Max random delay to stagger multiple hosts.";
          example = "1h";
        };
        persistent = mkOption {
          type = types.bool;
          default = true;
          description = "Run the update after a missed schedule (e.g. on next boot). Set false on desktops to avoid a mid-session rebuild firing unexpectedly.";
        };
        skipIfActiveSession = mkOption {
          type = types.bool;
          default = false;
          description = "Skip the update if a user session is actively in use (logind IdleHint=no). An idle session (locked screen / no recent input) still allows the update. Recommended for desktop hosts. Note: IdleHint reliability depends on the desktop environment reporting idle to logind.";
        };
        lowPriority = mkOption {
          type = types.bool;
          default = false;
          description = "Run nixos-rebuild with nice/ionice to reduce impact on foreground work. Recommended for desktop hosts.";
        };
        onlyOnAC = mkOption {
          type = types.bool;
          default = false;
          description = "Only run the update when on AC power (ConditionACPower). Recommended for laptops.";
        };
        shutdownAfterRebuild = mkOption {
          type = types.bool;
          default = false;
          description = "Power the system off after a successful automated rebuild. Only fires when a rebuild actually occurred (new commits pulled and rebuild succeeded).";
        };
      };
    };

    # -------------------------------------------------------------------------- #
    #                           HOMELAB CONFIGURATION                            #
    # -------------------------------------------------------------------------- #
    homelab = {
      dns = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Unbound DNS server with a local .lan zone for homelab service names. Intended for optiplex-nas only.";
        };
      };

      localCA = {
        enable = mkEnableOption "local step-ca ACME certificate authority for .lan services";
        port = mkOption {
          type = types.port;
          default = 9000;
          description = "Port for the step-ca ACME server to listen on (localhost only).";
        };
        trustCA = mkEnableOption "add the homelab root CA to the system trust store";
      };

      reverseProxy = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Nginx reverse proxy for homelab web services (routes .lan hostnames to local ports).";
        };
      };

      landingPage = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Serve a homelab dashboard at home.lan listing all service links.";
        };
      };

      samba = {
        enable = mkOption { 
          type = types.bool; 
          default = false; 
          description = "Enable Samba file sharing service."; 
        };
        private = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable a separate, private Samba share on a custom port.";
          };
          port = mkOption {
            type = types.port;
            default = 4445; # A non-standard port for the private share
            description = "The TCP port for the private Samba service to listen on.";
          };
          path = mkOption {
            type = types.str;
            default = "/mnt/private";
            description = "The absolute path for the private share.";
          };
          user = mkOption {
            type = types.str;
            # This cleverly defaults to the main user defined for the system
            default = config.customConfig.user.name;
            defaultText = "config.customConfig.user.name";
            description = "The user that will be forced for file operations on the private share.";
          };
        };
      };
      nasClient = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Mount the homelab NAS (optiplex-nas, 192.168.1.76) storage share via
            CIFS. Works on LAN and over WireGuard full-tunnel VPN.
            Credentials are managed via SOPS: add a `smb-credentials` key to
            secrets/common.yaml with the content:
              username=<samba-user>
              password=<samba-password>
          '';
        };
        mountPoint = mkOption {
          type = types.str;
          default = "/mnt/nas";
          description = "Local path where the NAS storage share will be mounted.";
        };
        serverAddress = mkOption {
          type = types.str;
          default = "192.168.1.76";
          description = ''
            IP or hostname of the NAS as reached from this host. Default is the
            legacy main-LAN IP; override for hosts that route to the NAS by a
            different address (e.g. gaming-pc reaches it via a dedicated LAN
            WireGuard tunnel at 192.168.100.76 post-migration).
          '';
        };
      };
      mediaSetup = {
        enable = lib.mkEnableOption "Enable the shared media setup";
        user = lib.mkOption {
          type = lib.types.str;
          description = "The primary user account for media ownership.";
        };
        storagePath = lib.mkOption {
          type = lib.types.str;
          description = "The path to the main storage pool.";
        };
        cachePath = lib.mkOption {
          type = lib.types.str;
          description = "The path to the fast cache drive.";
        };
      };
      jellyfin = {
        enable = mkOption {
          type = types.bool;
          default = false; # Default to false, enable explicitly for Jellyfin
          description = "Enable Jellyfin media server.";
        };
        hwTranscoding = mkOption {
          type = types.bool;
          default = false;
          description = "Enable hardware video transcoding.";
        };
      };
      arr = {
        prowlarr = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for Prowlarr
            description = "Enable Prowlarr, an indexer manager for Radarr and Sonarr.";
          };
        };
        radarr = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for Radarr
            description = "Enable Radarr, a movie collection manager.";
          };
        };
        sonarr = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for Sonarr
            description = "Enable Sonarr, a TV series collection manager.";
          };
        };
        bazarr = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly for Bazarr
            description = "Enable Bazarr, a subtitle manager for Radarr and Sonarr.";
          };
        };
      };

      transmission = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Transmission, a lightweight torrent client.";
        };
      };

      mullvad = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Mullvad VPN daemon for system-wide VPN.";
        };
      };

      jellyseerr = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Jellyseerr, a media request manager for Jellyfin.";
        };
      };

      flaresolverr = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable FlareSolverr, a Cloudflare bypass proxy for indexers.";
        };
      };

      mediaLinker = {
        enable = lib.mkEnableOption "media-linker service for per-user Jellyfin libraries";

        mediaUsers = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Directory name for this user under media/users/.";
              };
              jellyseerrId = mkOption {
                type = types.int;
                description = "Jellyseerr user ID (visible in Jellyseerr admin panel).";
              };
            };
          });
          default = [];
          description = "List of media users to create per-user Jellyfin libraries for.";
        };

        interval = mkOption {
          type = types.str;
          default = "5min";
          description = "How often to sync per-user libraries.";
        };

        envFile = mkOption {
          type = types.path;
          default = "/root/secrets/media-linker.env";
          description = "Path to environment file with JELLYSEERR_API_KEY, RADARR_API_KEY, SONARR_API_KEY.";
        };
      };

      nixCache = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable nix-serve to host a local Nix binary cache on port 5000.";
        };
        clientHost = mkOption {
          type = types.str;
          default = "192.168.1.76";
          description = ''
            Address at which the NAS nix binary cache (port 5000) is reached as a
            substituter from this host. Default is the legacy Main-LAN IP (a firewall
            alias post-migration, reachable from the LAN via rdr). Server-subnet hosts
            should override to 192.168.100.76 to reach it directly, since the legacy
            alias is not reachable from behind the firewall.
          '';
        };
      };

      flakeUpdater = {
        enable = mkEnableOption "weekly automated flake update orchestrator";
        repoDir = mkOption {
          type = types.str;
          default = "/home/lando/nixos-config";
          description = "Absolute path to the nixos-config git repository on this machine.";
        };
        repoOwner = mkOption {
          type = types.str;
          default = "landonreekstin";
          description = "GitHub repository owner (user or org).";
        };
        repoName = mkOption {
          type = types.str;
          default = "nixos-config";
          description = "GitHub repository name.";
        };
        gitUser = mkOption {
          type = types.str;
          default = "lando";
          description = "Local unix user to run git operations as (must have SSH access to GitHub).";
        };
        allHosts = mkOption {
          type = types.listOf types.str;
          default = [ "gaming-pc" "optiplex" "blaney-pc" "justus-pc" "asus-laptop" "asus-m15" "atl-mini-pc" "optiplex-nas" "mini-server" ];
          description = "All host names to build and include in the PR build matrix.";
        };
        blockLabel = mkOption {
          type = types.str;
          default = "update-blocked";
          description = "GitHub PR label that prevents auto-merge.";
        };
        autoMergeDays = mkOption {
          type = types.int;
          default = 6;
          description = ''
            Days after PR creation before auto-merging (if not blocked). Set to 6, not 7,
            because the updater runs Mondays 03:00 UTC but PRs open Mondays 04-09 UTC (after
            the beta-host build finishes), so the next Monday's check sees ~6d20h — integer 6.
            A threshold of 7 would defer the merge another full week for a 13-day soak.
          '';
        };
        betaHost = mkOption {
          type = types.str;
          default = "gaming-pc";
          description = "Host built first; PR is opened immediately after it completes so the beta soak starts ASAP.";
        };
        buildTimeoutMinutes = mkOption {
          type = types.int;
          default = 45;
          description = "Per-host build timeout in minutes. Hosts exceeding this are marked TIMEOUT in the PR table.";
        };
        githubTokenFile = mkOption {
          type = types.path;
          default = "/run/secrets/github-token";
          description = "Path to file containing a GitHub fine-grained PAT with contents:write and pull_requests:write.";
        };
      };

      vaultwarden = {
        enable = mkEnableOption "Vaultwarden password manager server";
        port = mkOption {
          type = types.port;
          default = 8222;
          description = "Port for Vaultwarden to listen on.";
        };
      };

      homeAssistant = {
        enable = mkEnableOption "Home Assistant Core smart home server";
        port = mkOption {
          type = types.port;
          default = 8123;
          description = "Port for Home Assistant to listen on.";
        };
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Override the Home Assistant package (e.g. to pin a newer version for backup restore compatibility).";
        };
      };

      wyoming = {
        enable = mkEnableOption "Wyoming voice pipeline (Whisper + Piper + openWakeWord + satellite)";
        satellite = {
          name = mkOption {
            type = types.str;
            default = "home";
            description = "Friendly name for the Wyoming satellite shown in Home Assistant.";
          };
          micDevice = mkOption {
            type = types.str;
            default = "hw:1,0";
            description = "ALSA device string for the microphone. Verify with `arecord -l` after install.";
          };
          sndDevice = mkOption {
            type = types.str;
            default = "hw:0,0";
            description = "ALSA device string for speaker output. Verify with `aplay -l` after install.";
          };
          awakeWav = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to WAV played when the wake word fires. Null uses wyoming-satellite's built-in sound.";
          };
          doneWav = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to WAV played when TTS finishes. Null uses wyoming-satellite's built-in sound.";
          };
          wakeWord = mkOption {
            type = types.str;
            default = "hey_jarvis";
            description = "openWakeWord model name passed to wyoming-satellite (e.g. hey_jarvis, ok_nabu).";
          };
          noiseSuppression = mkOption {
            type = types.ints.between 0 4;
            default = 0;
            description = "WebRTC noise-suppression level on the mic (0 = off, 4 = max — may distort).";
          };
          autoGain = mkOption {
            type = types.ints.between 0 31;
            default = 0;
            description = "Automatic gain control in dbFS (0 = off, 31 = loudest). Off is usually best in noisy rooms.";
          };
        };
        openwakeword = {
          threshold = mkOption {
            type = types.numbers.between 0.0 1.0;
            default = 0.5;
            description = "openWakeWord activation threshold (0.0-1.0). Higher = fewer false triggers.";
          };
          triggerLevel = mkOption {
            type = types.ints.unsigned;
            default = 1;
            description = "Consecutive activations required before a wake event fires. Higher = fewer detections.";
          };
        };
        whisper = {
          model = mkOption {
            type = types.str;
            default = "tiny-int8";
            description = "Whisper model variant (tiny, base, small, medium; append -int8 for quantized).";
          };
          language = mkOption {
            type = types.str;
            default = "en";
            description = "Language code for Whisper STT.";
          };
        };
        piper = {
          voice = mkOption {
            type = types.str;
            default = "en_US-lessac-medium";
            description = "Piper TTS voice identifier (e.g. en_US-lessac-medium).";
          };
        };
      };

      gameServers = {
        dataDir = mkOption {
          type = types.str;
          default = "/var/lib/game-servers";
          description = "Parent directory for all game server OCI container volume mounts.";
        };
        astroneer = {
          enable = mkEnableOption "Astroneer dedicated server (OCI container, autoStart = false)";
          port = mkOption {
            type = types.port;
            default = 7777;
            description = "Astroneer game port (UDP).";
          };
          queryPort = mkOption {
            type = types.port;
            default = 27777;
            description = "Astroneer server query port (UDP).";
          };
        };
        minecraftSurvival = {
          enable = mkEnableOption "Minecraft Survival server (Paper, OCI container, autoStart = false)";
          port = mkOption {
            type = types.port;
            default = 25565;
            description = "Minecraft Java edition TCP port.";
          };
        };
        minecraftMinigames = {
          enable = mkEnableOption "Minecraft Minigames server (Paper, OCI container, autoStart = false)";
          port = mkOption {
            type = types.port;
            default = 25566;
            description = "Minecraft Java edition TCP port.";
          };
        };
        minecraftBedrock = {
          enable = mkEnableOption "Minecraft Bedrock server (OCI container, autoStart = false)";
          port = mkOption {
            type = types.port;
            default = 19132;
            description = "Minecraft Bedrock IPv4 UDP port.";
          };
          portV6 = mkOption {
            type = types.port;
            default = 19133;
            description = "Minecraft Bedrock IPv6 UDP port.";
          };
        };
      };

      gameControl = {
        enable = mkEnableOption "Game Control dashboard (FastAPI + uvicorn)";
        port = mkOption {
          type = types.port;
          default = 8080;
          description = "Port for the Game Control web dashboard.";
        };
        tokenFile = mkOption {
          type = types.path;
          default = "/run/secrets/game-control-token";
          description = "Path to file containing the GAME_CONTROL_TOKEN secret.";
        };
        stateDir = mkOption {
          type = types.str;
          default = "/var/lib/game-control";
          description = "Directory for watchdog idle-timer state files (*.last_active).";
        };
        idleThresholdSecs = mkOption {
          type = types.int;
          default = 3600;
          description = "Seconds of zero players before the watchdog shuts down a server (default: 60 min).";
        };
      };

      gameBackup = {
        enable = mkEnableOption "game server and vaultwarden backups to NAS via restic (daily at 4am)";
        repository = mkOption {
          type = types.str;
          default = "/mnt/nas/backups/mini-server";
          description = "Restic repository path or URI. Defaults to the NAS CIFS mount.";
        };
        passwordFile = mkOption {
          type = types.path;
          default = "/run/secrets/restic-password";
          description = "Path to file containing the restic repository password.";
        };
      };

      article2pod = {
        enable = mkEnableOption "article2pod read-it-later podcast service";

        port = mkOption {
          type = types.port;
          default = 8100;
          description = "Port for the article2pod FastAPI service.";
        };

        kokoroPort = mkOption {
          type = types.port;
          default = 8880;
          description = "Port for the Kokoro-FastAPI TTS container.";
        };

        storagePath = mkOption {
          type = types.str;
          default = "/mnt/storage/podcasts";
          description = "Root directory for podcast audio files (on HDD storage).";
        };

        statePath = mkOption {
          type = types.str;
          default = "/var/lib/article2pod";
          description = "Directory for SQLite DB and transient state.";
        };

        modelsPath = mkOption {
          type = types.str;
          default = "/mnt/cache/article2pod/models";
          description = "Directory for Kokoro model weights (on NVMe cache).";
        };

        hostname = mkOption {
          type = types.str;
          default = "reader.lan";
          description = "Hostname for the nginx virtual host and feed URLs.";
        };

        podcastTitle = mkOption {
          type = types.str;
          default = "Article Podcast";
          description = "Title shown in podcast clients.";
        };

        podcastAuthor = mkOption {
          type = types.str;
          default = "lando";
          description = "Author shown in podcast clients.";
        };

        podcastDescription = mkOption {
          type = types.str;
          default = "Articles converted to audio episodes";
          description = "Feed description shown in podcast clients.";
        };

        flareSolverrUrl = mkOption {
          type = types.str;
          default = "http://localhost:8191";
          description = "FlareSolverr endpoint for JS-challenge bypass.";
        };

        ttsBackend = mkOption {
          type = types.enum [ "kokoro" "piper" ];
          default = "kokoro";
          description = "TTS backend: 'kokoro' (local container) or 'piper' (remote Wyoming endpoint).";
        };

        piperUrl = mkOption {
          type = types.str;
          default = "http://mini.lan:10200";
          description = "Piper Wyoming HTTP endpoint (used only when ttsBackend = piper).";
        };

        kokoroVoice = mkOption {
          type = types.str;
          default = "af_heart";
          description = "Kokoro voice identifier (see https://github.com/remsky/Kokoro-FastAPI for options).";
        };

        kokoroImage = mkOption {
          type = types.str;
          default = "ghcr.io/remsky/kokoro-fastapi:v0.5.0-cpu";
          description = ''
            Kokoro-FastAPI Docker image reference. Pin to a digest after first pull:
              docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/remsky/kokoro-fastapi:v0.5.0-cpu
          '';
        };

        tokenFile = mkOption {
          type = types.path;
          default = "/run/secrets/article2pod-token";
          description = "Path to file containing ARTICLE2POD_TOKEN env var (managed by sops-nix).";
        };
      };

      privateBackup = {
        enable = mkEnableOption "encrypted USB backup of /mnt/private (auto-triggers on USB plug-in)";
        sourcePath = mkOption {
          type = types.str;
          default = "/mnt/private";
          description = "Directory to back up.";
        };
        luksUuid = mkOption {
          type = types.str;
          description = ''
            LUKS UUID of the backup USB drive partition.
            Find it after plugging in the USB: blkid /dev/sdX
            Setup (one-time):
              dd if=/dev/urandom of=/root/secrets/backup-usb.key bs=4096 count=1
              chmod 600 /root/secrets/backup-usb.key
              cryptsetup luksAddKey /dev/sdX /root/secrets/backup-usb.key
          '';
        };
        keyFile = mkOption {
          type = types.str;
          default = "/root/secrets/backup-usb.key";
          description = "Path to the keyfile on the NAS used to open the backup USB LUKS volume.";
        };
        mapperName = mkOption {
          type = types.str;
          default = "backup-usb";
          description = "Device mapper name for the opened LUKS volume.";
        };
        mountPoint = mkOption {
          type = types.str;
          default = "/mnt/backup-usb";
          description = "Temporary mount point for the backup volume during rsync.";
        };
      };

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