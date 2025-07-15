# ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    
  ];
  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.customConfig.programs.kde.enable {

    # Enable Plasma6 Desktop Environment itself
    services.desktopManager.plasma6.enable = true;
    programs.xwayland.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-gtk
      ];
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WLAN = "1"; # Enable Ozone Wayland for KDE
    };

    # Add packages useful for KDE environment
    environment.systemPackages = with pkgs; [
      
    ];

  };
}