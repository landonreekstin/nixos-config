# ~/nixos-config/modules/nixos/desktop/display-manager.nix
# Handles selection and configuration of the display manager (SDDM or Cosmic Greeter)
{ config, pkgs, lib, ... }:

{
  # Option to choose the display manager in host configuration
  options.profiles.desktop.displayManager = lib.mkOption {
    type = lib.types.enum [ "cosmic" "greetd" "none" ]; # Available choices
    default = "none"; # Default to none, requiring an explicit choice in host config
    description = "Which display manager to use for graphical login.";
  };

  config = {
    # == Cosmic Greeter Configuration ==
    # Enable Cosmic Greeter service only if "cosmic" is selected
    services.displayManager.cosmic-greeter.enable = lib.mkIf (config.profiles.desktop.displayManager == "cosmic") true;

    # == Greetd + ReGreet Configuration ==
    services.greetd = {
      # Enable greetd service only if "greetd" is selected
      enable = lib.mkIf (config.profiles.desktop.displayManager == "greetd") true;
      settings = {
        default_session = {
          # Command launches Hyprland using the specific greeter config
          command = ''
            ${pkgs.hyprland}/bin/Hyprland -c /etc/greetd/hyprland-greeter.conf
          '';
          user = "greeter";
        };
      };
    };

    # == Greeter Hyprland Config File (managed by environment.etc) ==
    # Define the minimal config file for Hyprland when run by greetd
    environment.etc."greetd/hyprland-greeter.conf" = lib.mkIf (config.profiles.desktop.displayManager == "greetd") {
      text = ''
        # Minimal Hyprland config for greetd + regreet

        # Monitors (ensure rotation applies correctly for the greeter)
        monitor=HDMI-A-3,1920x1080,0x0,1,transform,1
        monitor=HDMI-A-1,preferred,1080x0,1
        monitor=HDMI-A-4,1920x1080,0x0,1,transform,1
        monitor=HDMI-A-2,preferred,1080x0,1

        # Basic Environment Variables
        env = XCURSOR_SIZE,24
        env = QT_QPA_PLATFORMTHEME,qt6ct # Or qt5ct depending on regreet build

        # Basic Input
        input { kb_layout = us; follow_mouse = 1; }

        # Basic Appearance (regreet handles most visuals)
        general { border_size = 1; layout = dwindle; }
        decoration { rounding = 0; drop_shadow = no; blur { enabled = false; } }
        animations { enabled = false; }

        # Execute ReGreet
        exec-once = ${pkgs.greetd.regreet}/bin/regreet

        # Minimal misc settings
        misc { disable_hyprland_logo = true; force_default_wallpaper = -1; } # No wallpaper needed here
      ''; # End text block
    }; # End environment.etc definition

    # == Packages needed for Greetd/ReGreet setup ==
    # Add required packages only if greetd is selected
    environment.systemPackages = lib.mkIf (config.profiles.desktop.displayManager == "greetd") [
        pkgs.greetd.greetd
        pkgs.greetd.regreet
        pkgs.hyprland # Needed for the greeter session
        pkgs.qt6.qtwayland # Often needed by regreet/Qt apps under Wayland
        # pkgs.qt5.qtwayland # Use if regreet uses Qt5
    ];

    # == Assertions ==
    # Ensure that configuration choices don't conflict
    assertions = [
      # Assertion 1: Only allow one display manager to be enabled simultaneously
      {
        assertion = builtins.length (lib.filter (x: x == true) [
          config.services.displayManager.cosmic-greeter.enable
          config.services.displayManager.sddm.enable
          # Add other potential display managers here if supported later
        ]) <= 1;
        message = "Configuration Error: Only one display manager (SDDM or Cosmic Greeter) can be enabled at a time. Check profiles.desktop.displayManager setting.";
      }
      # Assertion 2: Warn if a desktop profile is enabled but no display manager is selected (optional, can be noisy)
      # {
      #   assertion = !(
      #        (config.profiles.desktop.cosmic.enable || config.profiles.desktop.hyprland.enable) # Check relevant profiles
      #     && (config.profiles.desktop.displayManager == "none")
      #   );
      #   message = "Configuration Warning: A desktop profile (COSMIC or Hyprland) is enabled, but profiles.desktop.displayManager is set to 'none'. Graphical login might not work as expected.";
      # }
    ]; # End assertionssessionComman
  }; # End main config block
}