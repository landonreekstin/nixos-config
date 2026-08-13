# ~/nixos-config/hosts/vm-sandbox/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" "xfce" ];
    kde.kwallet.enable = false;
    displayManager = {
      enable = true;
      type = "sddm"; # sddm → autologin wired in vm-common
    };
  };

  # Autologins into the KDE aerotheme (windows7-alt) session by default — apps.defaultSet=kde.
  # XFCE ("Xfce Session") stays pickable at the SDDM chooser for on-VM theme checks, but the
  # real windows7-xfce test surface is physical gaming-pc (the VM's virgl scaling artifacts).
}
