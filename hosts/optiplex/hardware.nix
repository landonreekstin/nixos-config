# ~/nixos-config/hosts/optiplex/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware (GTX 1050) — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      package = "stable"; # GTX 1050 requires 580.xx legacy driver (not supported in 590.xx+)
    };
    # Monitor configuration for DM rotation (connector names from /sys/class/drm/*/status)
    # Currently only HDMI-A-3 (native OptiPlex) is connected - vertical orientation
    monitors = [
      { name = "HDMI-A-3"; rotation = "Rotated90"; }           # Native OptiPlex display (vertical)
      # Additional monitors can be added when connected
    ];
    peripherals = {
      enable = true; # Enable peripheral configurations
      openrgb.enable = true; # Enable OpenRGB for RGB control
      openrazer.enable = true; # Enable OpenRazer for Razer device support
      ckb-next.enable = false; # Enable CKB-Next for Corsair device support
      input-remapper.enable = true;
      solaar.enable = true;
    };
  };
}
