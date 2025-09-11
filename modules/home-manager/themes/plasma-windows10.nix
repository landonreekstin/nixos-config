# ~/nixos-config/modules/home-manager/themes/plasma-windows10.nix
{ lib, config, pkgs, ... }:

let
  # Only activate this module if the host config enables it
  cfg = config.customConfig;
  hmTheme = cfg.homeManager.themes.kde;
  isKdeActive = lib.elem "kde" cfg.desktop.environments;

in
{
  # This module is only imported if the user sets the kde theme to "windows10"
  # and has "kde" in their list of desktop environments.
  config = lib.mkIf (hmTheme == "windows10" && isKdeActive) {

    # Plasma-Manager configuration starts here
    programs.plasma = {
      enable = true;

      # High-level workspace settings
      workspace = {
        lookAndFeel = "org.kde.breeze.desktop"; # Standard light theme
        #iconTheme = "windows10-icons";
      };

      # A single panel at the bottom, mimicking the Windows taskbar
      panels = [{
        location = "bottom";
        height = 36; # A fairly standard panel height
        widgets = [
          # Start Menu (Kickoff)
          "org.kde.plasma.kickoff"
          # Spacer to push items apart
          "org.kde.plasma.panelspacer"
          # Task Manager (for open applications)
          "org.kde.plasma.icontasks"
          # System Tray
          "org.kde.plasma.systemtray"
          # Digital Clock
          "org.kde.plasma.digitalclock"
          # Show Desktop button
          "org.kde.plasma.showdesktop"
        ];
      }];
    };

    # Add the icon theme package to the user's profile
    home.packages = with pkgs; [
      #windows10-icons
    ];

  };
}