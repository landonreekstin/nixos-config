# ~/nixos-config/modules/nixos/hardware/nvidia.nix
{ config, pkgs, lib, ... }:
{
  config = lib.mkIf config.customConfig.hardware.nvidia.enable {
    # Enable proprietary Nvidia drivers
    hardware.nvidia = {
      open = false; # Use proprietary driver
      modesetting.enable = true; # Needed for Wayland
      powerManagement.enable = true; # Recommended
      # package = config.boot.kernelPackages.nvidiaPackages.stable; # Or specify version if needed
    };

    services.xserver.videoDrivers = [ "nvidia" ]; # Ensure X11 & Wayland use Nvidia driver

    # Ensure necessary firmware is available
    hardware.enableRedistributableFirmware = lib.mkDefault true; # Use mkDefault so host config can override to false if needed

    # Allow unfree packages (required for Nvidia drivers)
    nixpkgs.config.allowUnfree = lib.mkDefault true; # Use mkDefault
  };
}