# In ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  config = lib.mkIf (lib.elem "kde" config.customConfig.desktop.environments) {

    # 1. Enable Plasma6 Desktop Environment
    services.desktopManager.plasma6.enable = true;

    # 2. Configure the top-level XDG Portal service
    # We enable the service and ensure all necessary backends are installed.
    # The session itself will pick the correct one to use at runtime.
    xdg.portal = {
      enable = true;
      # REMOVED the static 'config' block.
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-hyprland
      ];
      xdgOpenUsePortal = true;
    };

    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      kdePackages.xwaylandvideobridge

      kdePackages.kcalc
    ];

    # 4. Keep other necessary services
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    programs.xwayland.enable = true;

    # REMOVED the environment.sessionVariables block that set XDG_CURRENT_DESKTOP.
  };
}