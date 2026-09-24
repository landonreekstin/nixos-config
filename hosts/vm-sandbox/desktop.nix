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

  # Autologins into the stock-Breeze KDE session by default — apps.defaultSet=kde. This VM is
  # kept on "kde" deliberately: it is the only Plasma test surface for the hosts that still run
  # it (optiplex, asus-laptop, asus-m15, atl-mini-pc, justus-pc) now that gaming-pc and
  # blaney-pc are Hyprland+XFCE only and aerothemeplasma is selected by nothing.
  # XFCE ("Xfce Session") stays pickable at the SDDM chooser for on-VM theme checks, but the
  # real windows7-xfce test surface is physical gaming-pc (the VM's virgl scaling artifacts).
}
