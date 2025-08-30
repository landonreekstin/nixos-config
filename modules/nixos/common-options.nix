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
        type = types.listOf (types.enum [ "hyprland" "cosmic" "kde" "pantheon" "none" ]);
        default = []; # Default to an empty list
        example = [ "kde" "hyprland" ];
        description = "A list of desktop environments or window managers to make available on the system.";
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
          type = types.enum [ "sddm" "gdm" "greetd" "ly" "pantheon" "none" ]; # Add more as needed
          default = "sddm"; # A common default, adjust as preferred
          description = "Which display manager to use if displayManager.enable is true. 'none' means no DM managed by this option.";
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
            type = types.enum [ "windows7" "none" ];
            default = "none";
            description = "Set the Plasma theme for Home Manager.";
          };
        hyprland = mkOption {
          type = types.enum [ "future-aviation" "none" ];
          default = "none";
          description = "Set the Hyprland theme for Home Manager.";
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
      homeManager = mkOption { # User-specific packages
        type = with types; listOf package;
        default = [];
        description = "List of additional user-specific packages to install via Home Manager.";
        example = "with pkgs; [ cowsay neofetch ]";
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
      };
      # You could add other profiles like 'development', 'server', 'htpc' here later
    };

    # -------------------------------------------------------------------------- #
    #                             HARDWARE AND PERIPHERALS                       #
    # -------------------------------------------------------------------------- #
    hardware = {
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
            type = types.str;
            default = ""; # Default to empty, can be set to specific GPU ID if needed
            description = "The NVIDIA GPU ID for PRIME configurations on laptops.";
          };
          amdgpuID = mkOption {
            type = types.str;
            default = ""; # Default to empty, can be set to specific GPU ID if needed
            description = "The AMD GPU ID for PRIME configurations on laptops.";
          };
        };
        # You could add more nvidia options here: powerManagement, openDrivers, etc.
      };
      powerManagement = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable power management. May overwrite session GUI-set settings.";
        };
        tlp = {
          enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable tlp power optimiztion tool.";
        };
        };
      };
      # Add options for amdgpu, intel, bluetooth etc. here later
      # CORSAIR KEYBOARD, rgb management
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
      nixai = {
        enable = mkOption { 
          type = types.bool; 
          default = false; 
          description = "Enable NixAI MCP server."; 
        };
        # You can add more options for NixAI here, like model, port, etc.
      };
      # Add options for other services like syncthing, printing, etc.
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