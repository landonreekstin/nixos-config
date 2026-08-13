# ~/nixos-config/hosts/justus-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true;
    };
    peripherals = {
      enable = true; # Enable peripheral configurations
      openrgb.enable = true; # Enable OpenRGB for RGB control
      openrazer.enable = false; # Enable OpenRazer for Razer device support
      ckb-next.enable = false; # Enable CKB-Next for Corsair device support
      input-remapper.enable = true;
      solaar.enable = false;
    };
  };

  # === Additional nixos configuration for this host ===
  #services.g810-led.package = pkgs.g810-led; # Ensure the g810-led package is available
  #services.g810-led.enable = true; # Enable Logitech G810 keyboard LED control
}
