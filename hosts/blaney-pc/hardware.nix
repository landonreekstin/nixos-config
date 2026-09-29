# ~/nixos-config/hosts/blaney-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
    };
    peripherals = {
      enable = true; # Enable peripheral configurations
      openrgb.enable = true; # Enable OpenRGB for RGB control
      openrazer.enable = true; # Enable OpenRazer for Razer device support
      ckb-next.enable = false; # Enable CKB-Next for Corsair device support
      input-remapper.enable = true;
      solaar.enable = true;
    };
    wifi.waybar.enable = true;  # USB WiFi dongle (wlp38s0f3u1) — picker in the Hyprland bar
  };

  # Firmware updates (`fwupdmgr refresh && fwupdmgr update`). This used to arrive as a
  # `mkDefault true` from services.desktopManager.plasma6 and silently disappeared when
  # KDE was dropped from desktop.environments — it has nothing to do with the desktop, so
  # declare it here instead of letting a session choice decide whether this machine can
  # update its firmware.
  services.fwupd.enable = true;
}
