# ~/nixos-config/hosts/asus-m15/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true;
      laptop = {
        enable = true;
        intelBusID = "PCI:0:2:0";
        nvidiaID = "PCI:1:0:0";
      };
    };
    peripherals = {
      enable = true;
      asus.enable = true;
    };
    display.backlight.enable = true;
    kbdBacklight.enable = true;
    battery.enable = true;
    wifi.waybar.enable = true;  # Roaming host — WiFi picker in the Hyprland bar
  };
}
