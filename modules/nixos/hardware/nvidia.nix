# ~/nixos-config/modules/nixos/hardware/nvidia.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.nvidia;

in
{
  config = lib.mkIf cfg.enable {

    # Enable proprietary Nvidia drivers
    hardware.nvidia = {
      open = false; # Use proprietary driver
      modesetting.enable = true; # Needed for Wayland
      powerManagement.enable = true; # Recommended
      # package = config.boot.kernelPackages.nvidiaPackages.stable; # Or specify version if needed
      # === Laptop-specific options ===
      prime = {
        #offload.enable = lib.mkDefault cfg.laptop.enable;
        sync.enable = lib.mkDefault cfg.laptop.enable;
        offload.enable = false;
        amdgpuBusId = lib.mkDefault cfg.laptop.amdgpuID or null; # AMD GPU ID for PRIME
        intelBusId = lib.mkDefault cfg.laptop.intelBusID or null; # Intel GPU ID for PRIME (if applicable)
        nvidiaBusId = lib.mkDefault cfg.laptop.nvidiaID; # Nvidia GPU ID for
      };
    };

    services.xserver.videoDrivers = [ "nvidia" ]; # Ensure X11 & Wayland use Nvidia driver

    # Ensure necessary firmware is available
    hardware.enableRedistributableFirmware = lib.mkDefault true; # Use mkDefault so host config can override to false if needed

    # Allow unfree packages (required for Nvidia drivers)
    nixpkgs.config.allowUnfree = lib.mkDefault true; # Use mkDefault

  };
}