# ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, ... }:

{
  # ==> Option Definition <==
  options.profiles.desktop.kde.enable = lib.mkEnableOption "KDE Plasma Desktop Environment profile";

  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.profiles.desktop.kde.enable {

    # Enable the Plasma 6 Desktop Environment
    services.desktopManager.plasma6.enable = true;

    # Enable basic Xorg server support (fonts, input, etc.)
    # Needed even for Wayland sessions usually. mkDefault allows COSMIC to override it.
    services.xserver.enable = lib.mkDefault true;

    # Enable SDDM display manager *only if* it's selected
    services.displayManager.sddm = {
        enable = lib.mkIf (config.profiles.desktop.displayManager == "sddm") true;
        # Use Breeze theme for SDDM if enabled (part of plasma-workspace)
        theme = lib.mkDefault "breeze";
    };


    # Add core KDE packages
    environment.systemPackages = with pkgs; [
      # plasma-workspace includes fundamentals like shell, kwin, systemsettings
      # We might not need to list it explicitly if plasma6.enable pulls it in,
      # but being explicit can sometimes help. Let's omit it for now.
      kdePackages.konsole # KDE Terminal
      kdePackages.dolphin # KDE File Manager
      kdePackages.ark     # KDE Archiving tool
      kdePackages.kaccounts-integration # For online accounts integration
    ];

    # Enable necessary services often used with Plasma
    services.power-profiles-daemon.enable = lib.mkDefault true; # Modern power management
    # Consider adding services.flatpak.enable = true; if you plan to use Flatpaks heavily

  };
}
