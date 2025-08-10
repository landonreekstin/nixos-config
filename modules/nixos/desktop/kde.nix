# In ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  config = lib.mkIf config.customConfig.programs.kde.enable {

    # 1. Enable Plasma6 Desktop Environment
    services.desktopManager.plasma6.enable = true;

    # 2. Configure the top-level XDG Portal service
    # This is the correct location for this block.
    xdg.portal = {
      enable = true;
      config = {
        plasma.default = [ "kde" "gtk" ];
        common.default = [ "gtk" ];
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-hyprland
      ];
      xdgOpenUsePortal = true;
    };

    # 3. CRITICAL FIX: Forcefully install the KDE portal package system-wide.
    # This ensures its systemd service file is always available.
    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      kdePackages.xwaylandvideobridge
    ];

    # 4. Keep other necessary services and variables
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    programs.xwayland.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "KDE";
    };
  };
}