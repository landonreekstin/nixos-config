# ~/nixos-config/modules/nixos/desktop/display-manager.nix
{ config, pkgs, lib, ... }:

{
  options.profiles.desktop.displayManager = lib.mkOption {
    type = lib.types.enum [ "cosmic" "sddm" "none" ]; # Add others like "gdm" if needed later
    default = "none"; # Default to none, force host to choose
    description = "Which display manager to use for graphical login.";
  };

  config = {
    # This module itself doesn't enable services directly based on the option.
    # It just defines the option. The individual DE modules (cosmic.nix, hyprland.nix)
    # check this option's value to conditionally enable their preferred DM service.
    # ==> Configure SDDM Service <==
    services.displayManager.sddm = {
      enable = lib.mkIf (config.profiles.desktop.displayManager == "sddm") true;
      # Use mkDefault so other modules could potentially override if needed,
      # though usually not necessary for the theme here.
      theme = lib.mkDefault "breeze"; # Default theme, requires pkgs.plasma-workspace or similar
      # Consider adding pkgs.plasma-workspace to systemPackages if using breeze theme
      # Or install another SDDM theme package and set its name here.
      # Example using wherevers-dark theme:
      # theme = "wherevers-dark";
      wayland.enable = lib.mkIf (config.profiles.desktop.displayManager == "sddm") true; # Enable Wayland session handling
    };

    # ==> Configure Cosmic Greeter Service <==
    # (Move the conditional enable from cosmic.nix to here for consistency)
    services.displayManager.cosmic-greeter.enable = lib.mkIf (config.profiles.desktop.displayManager == "cosmic") true;


    # Ensure only one display manager service is active by asserting that
    # the sum of enabled DM services is at most 1.
    assertions = [
      {
        assertion = builtins.length (lib.filter (x: x == true) [
          config.services.displayManager.cosmic-greeter.enable
          config.services.displayManager.sddm.enable
          # Add other DMs here if supported later (e.g., config.services.displayManager.gdm.enable)
        ]) <= 1;
        message = "Only one display manager service can be enabled at a time.";
      }
      {
        # Warn if a DE profile is enabled but no display manager is selected
        assertion = !(
             (config.profiles.desktop.cosmic.enable || config.profiles.desktop.kde.enable)
          && (config.profiles.desktop.displayManager == "none")
        );
        message = "Warning: A desktop profile is enabled, but profiles.desktop.displayManager is set to 'none'. Choose 'cosmic' or 'sddm'.";
      }
    ];
  };
}
