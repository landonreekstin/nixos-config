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

  # The AMD 500-series chipset xHCI controller (0000:02:00.0, USB bus 1/2 — the G915
  # receiver lives there) fails S3 resume: "xHC error in resume, USBSTS 0x401, Reinit",
  # then Logitech HID++ protocol errors and dead input until the receiver is replugged.
  # Unbinding and rebinding the controller after wake re-enumerates it from scratch.
  # Not done before suspend, so a keypress can still wake the PC.
  powerManagement.resumeCommands = ''
    xhci=0000:02:00.0
    if [ -e /sys/bus/pci/drivers/xhci_hcd/$xhci ]; then
      echo $xhci > /sys/bus/pci/drivers/xhci_hcd/unbind
      sleep 1
    fi
    echo $xhci > /sys/bus/pci/drivers/xhci_hcd/bind
  '';
}
