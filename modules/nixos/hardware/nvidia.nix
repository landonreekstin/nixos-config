# ~/nixos-config/modules/nixos/hardware/nvidia.nix
{ config, pkgs, lib, unstablePkgs, ... }:

let
  cfg = config.customConfig.hardware.nvidia;

in
{
  config = lib.mkIf cfg.enable {

    #boot.kernelPackages = lib.mkDefault unstablePkgs.linuxPackages_latest;

    # Enable proprietary Nvidia drivers
    hardware.nvidia = {
      open = false; # Use proprietary driver
      modesetting.enable = true; # Needed for Wayland
      powerManagement = {
        enable = true; # Recommended
        finegrained = cfg.laptop.enable;
      };
      # package = config.boot.kernelPackages.nvidiaPackages.stable; # Or specify version if needed
      # === Laptop-specific options ===
      prime = lib.mkMerge [
        # --- Unconditional prime settings for laptops ---
        (lib.mkIf cfg.laptop.enable {
          sync.enable = true;
          offload.enable = false; # Set your desired default for offload
          # This assumes nvidiaID will always be set for a prime setup
          nvidiaBusId = cfg.laptop.nvidiaID;
        })

        # --- Conditional bus ID settings ---
        # Only add amdgpuBusId if a value is provided
        (lib.mkIf (cfg.laptop.amdgpuID != null) {
          amdgpuBusId = cfg.laptop.amdgpuID;
        })

        # Only add intelBusId if a value is provided
        (lib.mkIf (cfg.laptop.intelBusID != null) {
          intelBusId = cfg.laptop.intelBusID;
        })
      ];
    };

    services.xserver.videoDrivers = [ "nvidia" ]; # Ensure X11 & Wayland use Nvidia driver

    # Ensure necessary firmware is available
    hardware.enableRedistributableFirmware = lib.mkDefault true; # Use mkDefault so host config can override to false if needed

    # Allow unfree packages (required for Nvidia drivers)
    nixpkgs.config.allowUnfree = lib.mkDefault true; # Use mkDefault

  };
}