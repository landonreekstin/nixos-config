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
    };

    bootloader = {
      quietBoot = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly for quiet boot
        description = "Whether to enable quiet boot (suppress boot messages).";
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
        type = types.listOf (types.enum [ "hyprland" "cosmic" "kde" "none" ]);
        default = []; # Default to an empty list
        example = [ "kde" "hyprland" ];
        description = "A list of desktop environments or window managers to make available on the system.";
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
      hyprland = {
        applications = {
          taskManager = mkOption {
            type = types.str;
            default = "${pkgs.btop-rocm}/bin/btop";
            description = "Command to launch task manager (Ctrl+Shift+Escape in terminal).";
            example = "\${pkgs.htop}/bin/htop";
          };
          ide = mkOption {
            type = types.str;
            default = "${pkgs.vscode}/bin/code";
            description = "Command to launch IDE (Super+I).";
            example = "\${pkgs.neovim}/bin/nvim";
          };
          editor = mkOption {
            type = types.str;
            default = "${pkgs.kdePackages.kate}/bin/kate";
            description = "Command to launch text editor (Super+T).";
            example = "\${pkgs.vim}/bin/vim";
          };
          fileManagerTUI = mkOption {
            type = types.str;
            default = "${pkgs.yazi}/bin/yazi";
            description = "Command to launch terminal file manager (Super+F in terminal).";
            example = "\${pkgs.ranger}/bin/ranger";
          };
          browser = mkOption {
            type = types.str;
            default = "${pkgs.librewolf}/bin/librewolf";
            description = "Command to launch primary browser (Super+B).";
            example = "\${pkgs.firefox}/bin/firefox";
          };
          browserAlt = mkOption {
            type = types.str;
            default = "${pkgs.brave}/bin/brave";
            description = "Command to launch alternative browser (Super+Shift+B).";
            example = "\${pkgs.chromium}/bin/chromium";
          };
          music = mkOption {
            type = types.str;
            default = "${pkgs.spotify}/bin/spotify --enable-features=UseOzonePlatform --ozone-platform=wayland";
            description = "Command to launch music player (Super+M).";
            example = "\${pkgs.rhythmbox}/bin/rhythmbox";
          };
          chat = mkOption {
            type = types.str;
            default = "${pkgs.discord}/bin/discord";
            description = "Command to launch chat application (Super+D).";
            example = "\${pkgs.element-desktop}/bin/element-desktop";
          };
          gaming = mkOption {
            type = types.str;
            default = "steam";
            description = "Command to launch primary gaming platform (Super+G).";
            example = "\${pkgs.steam}/bin/steam";
          };
          gamingAlt = mkOption {
            type = types.str;
            default = "${pkgs.lutris}/bin/lutris";
            description = "Command to launch alternative gaming platform (Super+Shift+G).";
            example = "\${pkgs.heroic}/bin/heroic";
          };
        };
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
        gammastep = {
          enable = mkOption {
            type = types.bool;
            default = (lib.elem "hyprland" config.customConfig.desktop.environments); # Enable by default, can be overridden in user config
            description = "Whether to enable gammastep for night light adjustments.";
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
        wallpaper = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Absolute path to the desktop wallpaper. If null, a default will be used.";
          example = "/path/to/my/wallpaper.png";
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

    apps = { # Specific application configurations or preferences
      defaultBrowser = mkOption {
        type = types.nullOr types.str; # Store package name as string, e.g., "firefox"
        default = "firefox";
        description = "The package name of the default web browser (e.g., 'firefox', 'librewolf').";
      };
      # You could add more app-specific toggles or settings here, e.g.:
      # terminalEmulator = mkOption { type = types.enum ["kitty" "alacritty" "foot"]; default = "kitty"; };
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
      nvidia = {
          enable = mkOption {
            type = types.bool;
            default = false; # Default to false, enable explicitly on NVIDIA machines
            description = "Enable NVIDIA drivers and related configuration.";
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
            default = false; # Default to false, enable explicitly for Razer device support
            description = "Enable OpenRazer for Razer device support.";
          };
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
        # This structure allows for a client module to be added later, like so:
        # client = {
        #   enable = mkOption { ... };
        # };
      };
    };

    # -------------------------------------------------------------------------- #
    #                           HOMELAB CONFIGURATION                            #
    # -------------------------------------------------------------------------- #
    homelab = {
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
    };

    # -------------------------------------------------------------------------- #
    #                        NIX & SYSTEM OPTIMIZATIONS                          #
    # -------------------------------------------------------------------------- #

  }; # End of customConfig option set
  
}