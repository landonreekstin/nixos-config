# ~/nixos-config/modules/nixos/desktop/display-manager.nix
# Handles selection and configuration of the display manager (SDDM or Cosmic Greeter)
{ config, pkgs, lib, ... }:

{
  # Option to choose the display manager in host configuration
  options.profiles.desktop.displayManager = lib.mkOption {
    type = lib.types.enum [ "cosmic" "sddm" "none" ]; # Available choices
    default = "none"; # Default to none, requiring an explicit choice in host config
    description = "Which display manager to use for graphical login.";
  };

  config = {
    # == SDDM Configuration ==
    services.displayManager.sddm = {
      # Enable SDDM service only if "sddm" is selected
      enable = lib.mkIf (config.profiles.desktop.displayManager == "sddm") true;

      # Set the theme for SDDM (requires theme package to be installed)
      theme = lib.mkDefault "sugar-dark"; # Defaulting to Breeze theme

      # Configure Wayland-specific settings for SDDM
      wayland.enable = lib.mkIf (config.profiles.desktop.displayManager == "sddm") true;

    }; # End sddm block

    # == Cosmic Greeter Configuration ==
    # Enable Cosmic Greeter service only if "cosmic" is selected
    services.displayManager.cosmic-greeter.enable = lib.mkIf (config.profiles.desktop.displayManager == "cosmic") true;

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