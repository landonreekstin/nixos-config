# In ~/nixos-config/modules/nixos/desktop/kde.nix
{ config, pkgs, lib, inputs, ... }:

{
  config = lib.mkIf (lib.elem "kde" config.customConfig.desktop.environments) {

    services.desktopManager.plasma6.enable = true;

    xdg.portal = {
      enable = true;

      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-hyprland
      ];
      xdgOpenUsePortal = true;
    };

    environment.systemPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde

      kdePackages.kcalc
      kdePackages.kate
    ];

    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    programs.xwayland.enable = true;
  };
}