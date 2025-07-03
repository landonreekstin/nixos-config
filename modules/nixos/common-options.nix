# ~/nixos-config/modules/nixos/common-options.nix
{ lib, pkgs, config /* config is the final NixOS config being built */, ... }:

# This top-level option group will hold all our custom configurations.
# We use 'customConfig' to avoid potential conflicts with existing NixOS 'config' attributes.
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
      shell = mkOption {
        type = types.nullOr types.package; # Allows specifying a shell package or using system default.
        default = pkgs.bash; # Example default, you can change to pkgs.bash or null.
        description = "The default shell for the primary user. Ex. 'bash', 'zsh', 'fish'.";
        example = "pkgs.fish";
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
      environment = mkOption {
        type = types.enum [ "hyprland" "cosmic" "kde" "none" ]; # Add more as you support them
        default = "none";
        description = "The primary desktop environment or window manager to enable system-wide.";
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
          type = types.enum [ "sddm" "gdm" "greetd" "ly" "none" ]; # Add more as needed
          default = "sddm"; # A common default, adjust as preferred
          description = "Which display manager to use if displayManager.enable is true. 'none' means no DM managed by this option.";
        };
      };
    };

    # Enables for specific system-level programs or services related to desktops
    # These are distinct from homeManagerModules which are user-level.
    programs = {
      hyprland = { # System-level setup for Hyprland (e.g., programs.hyprland.enable)
        enable = mkOption {
          type = types.bool;
          default = (config.customConfig.desktop.environment == "hyprland");
          defaultText = literalExpression ''(config.customConfig.desktop.environment == "hyprland")'';
          description = "Whether to enable system-level Hyprland configurations (e.g., NixOS module for Hyprland).";
        };
      };
      cosmic = { # System-level setup for COSMIC DE
        enable = mkOption {
          type = types.bool;
          default = (config.customConfig.desktop.environment == "cosmic");
          defaultText = literalExpression ''(config.customConfig.desktop.environment == "cosmic")'';
          description = "Whether to enable system-level COSMIC DE configurations.";
        };
      };
      kde = { # System-level setup for Plasma6 DE
        enable = mkOption {
          type = types.bool;
          default = (config.customConfig.desktop.environment == "kde");
          defaultText = literalExpression ''(config.customConfig.desktop.environment == "kde")'';
          description = "Whether to enable system-level KDE PLasma DE configurations.";
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
            default = (config.customConfig.desktop.environment == "hyprland"); # Enable by default, can be overridden in user config
            description = "Whether to enable gammastep for night light adjustments.";
          };
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
        # You could add more nvidia options here: powerManagement, openDrivers, etc.
      };
      # Add options for amdgpu, intel, bluetooth etc. here later
      # CORSAIR KEYBOARD, rgb management
    };

    # -------------------------------------------------------------------------- #
    #                             SERVICES (NixOS Level)                         #
    # -------------------------------------------------------------------------- #
    services = {
      ssh = {
        enable = mkOption { type = types.bool; default = false; description = "Enable OpenSSH server."; };
        # port = mkOption { type = types.port; default = 22; };
      };
      vscodeServer = {
        enable = mkOption { type = types.bool; default = false; description = "Enable vscode server."; };
        # port = mkOption { type = types.port; default = 22; };
      };
      nixai = {
        enable = mkOption { type = types.bool; default = false; description = "Enable NixAI MCP server."; };
        # You can add more options for NixAI here, like model, port, etc.
      };
      # Add options for other services like syncthing, printing, etc.
    };

    # -------------------------------------------------------------------------- #
    #                        NIX & SYSTEM OPTIMIZATIONS                          #
    # -------------------------------------------------------------------------- #

  }; # End of customConfig option set
  
}