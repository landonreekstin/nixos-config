# ~/nixos-config/modules/nixos/desktop/display-manager.nix
# Handles selection and configuration of the display manager (SDDM or Cosmic Greeter)
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.desktop.displayManager;
in
lib.mkIf cfg.enable {

  # == SDDM Configuration ==
  services.displayManager.sddm = lib.mkIf (cfg.type == "sddm") {
    enable = true;
    theme = "sugar-dark";
    wayland = {
      enable = true;
    };
  };
  
  # == Cosmic Greeter Configuration ==
  services.displayManager.cosmic-greeter.enable = lib.mkIf (cfg.type == "cosmic") true;

  # == Cosmic Greeter Configuration ==
  services.displayManager.ly.enable = lib.mkIf (cfg.type == "ly") true;

  # == Greetd + ReGreet Configuration ==
  services.greetd = lib.mkIf (cfg.type == "greetd") {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.hyprland}/bin/Hyprland -c /etc/greetd/hyprland-greeter.conf
        '';
        user = "greeter";
      };
    };
  };

  # == Auto-Login / Direct Session Start Configuration ==
  # Enable these only if 'none' is selected AND a target desktop profile is enabled
  # NOTE: This currently prioritizes Hyprland if both Cosmic and Hyprland are enabled.
  #       A more complex setup could allow choosing the autologin target.
  # Auto login with the configured user if no display manager is selected and a desktop profile is enabled
  services.getty.autologinUser = lib.mkIf (cfg.type == "none" && config.customConfig.desktop.enable) config.customConfig.user.name;

  # Ensure XDG Desktop Portal for Hyprland is available when autologging into it
  xdg.portal = lib.mkIf (cfg.type == "none" && config.customConfig.programs.hyprland.enable && config.customConfig.desktop.environment == "hyprland") {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    # Optionally add GTK portal as fallback
    # extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };
    # Add portal config for COSMIC if needed when autologging into it


  # ==> Create /etc/regreet.toml directly using environment.etc <==
  environment.etc."greetd/regreet.toml" = lib.mkIf (cfg.type == "greetd") {
    # Target path: /etc/greetd/regreet.toml
    text = ''
      # regreet configuration generated directly

      [background]
      path = "/etc/greetd/concorde-vertical-art.jpg"
      fit = "cover"

      # Add any other regreet settings directly here in TOML format
      # [theme]
      # name = "Adwaita-Dark" # Example

      # [icons]
      # name = "breeze" # Example
    '';
    mode = "0444"; # Read-only
  };

  # == Deploy Greeter Wallpaper File ==
  environment.etc."greetd/concorde-vertical-art.jpg" = lib.mkIf (cfg.type == "greetd") {
    # Target path: /etc/greetd/concorde-vertical-art.jpg
    source = ../../../assets/wallpapers/concorde-vertical-art.jpg; # Path relative to this Nix file
    mode = "0444"; # Read-only is appropriate
  };

  # == Greeter Hyprland Config File (managed by environment.etc) ==
  # Define the minimal config file for Hyprland when run by greetd
  environment.etc."greetd/hyprland-greeter.conf" = lib.mkIf (cfg.type == "greetd") {
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

  # == Packages needed based on DM selection (Using lib.optionals) ==
  environment.systemPackages =
    # Use lib.optionals which returns a list or []
    (lib.optionals (cfg.type == "sddm") [
      pkgs.sddm-sugar-dark
    ])
    ++ # Concatenate the lists
    (lib.optionals (cfg.type == "greetd") [
      pkgs.greetd.greetd
      pkgs.greetd.regreet
      pkgs.hyprland
      pkgs.qt6.qtwayland
      pkgs.libjpeg pkgs.gdk-pixbuf pkgs.librsvg pkgs.qt6.qtimageformats
    ])
    ++
    (lib.optionals (cfg.type == "none" && config.customConfig.programs.hyprland.enable) [
      pkgs.xdg-desktop-portal-hyprland
    ]);

  # == Assertions ==
  # Ensure that configuration choices don't conflict
  assertions = [
    # Assertion 1: Only allow one display manager to be enabled simultaneously
    {
      assertion = builtins.length (lib.filter (x: x == true) [
        config.services.displayManager.cosmic-greeter.enable or false # Use 'or false' in case module isn't evaluated
        config.services.displayManager.sddm.enable or false
        config.services.displayManager.ly.enable or false
        config.services.greetd.enable or false
      ]) <= 1;
      message = "Configuration Error: Only one display manager (SDDM, Greetd, or Cosmic Greeter) can be enabled at a time. Check profiles.desktop.displayManager setting.";
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
}