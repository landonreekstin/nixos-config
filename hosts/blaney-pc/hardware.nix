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
  };
}
