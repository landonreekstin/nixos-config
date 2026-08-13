# ~/nixos-config/hosts/mini-server/desktop.nix
{ config, pkgs, lib, ... }:

{
  # Headless from customConfig perspective; GNOME is configured via raw NixOS options below
  customConfig.desktop = {
    environments = [ "none" ];
    displayManager = {
      enable = false;
      type = "none";
    };
  };

  # GNOME desktop — keep for TV use; flip to headless when a dedicated TV device exists.
  # customConfig.desktop doesn't model GNOME yet; configure directly here.
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "gnome-session";
  services.xrdp.openFirewall = true;
}
