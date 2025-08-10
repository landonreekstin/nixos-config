# ../../modules/home-manager/system/xdg.nix
{ config, lib, pkgs, osConfig, ... }:
{
  # Configure XDG user directories (Desktop, Documents, etc.)
  xdg.userDirs = {
    enable = true;
    createDirectories = true; # Optional: create them if they don't exist
  };

  # Fixes KDE screen share
  xdg.portal.extraPortals = osConfig.xdg.portal.extraPortals;

  # Configure XDG Portals
  xdg = {
    enable = true;
    portal.config = {
      common = {
        default = "*";
      };
    };
  };
    # Note: The installation of portal backend packages (e.g., pkgs.xdg-desktop-portal-hyprland)
    # is typically handled in the system's configuration.nix (environment.systemPackages)
    # as they often need system-level D-Bus services.
    # If you need to ensure they are available for Home Manager to configure them,
    # you might list them in home.packages as well, or ensure system config provides them.
    # For now, this module focuses on the xdg.portal configuration.
 
}