# ~/nixos-config/modules/nixos/hardware/nvidia.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.hardware.nvidia;

in
{
  options.customConfig.hardware.nvidia = with lib; {
      enable = mkOption {
        type = types.bool;
        default = false; # Default to false, enable explicitly on NVIDIA machines
        description = "Enable NVIDIA drivers and related configuration.";
      };
      package = mkOption {
        type = types.enum [ "latest" "production" "stable" "legacy_535" "legacy_470" "legacy_390" ];
        default = "latest";
        description = ''
          Which NVIDIA driver package to use. Options:
          - "latest" - Latest driver (may drop support for older GPUs)
          - "production" - Production branch driver
          - "stable" - Stable branch (580.xx series, supports GTX 1000 series)
          - "legacy_535" - Legacy 535.xx branch
          - "legacy_470" - Legacy 470.xx branch (for Kepler GPUs)
          - "legacy_390" - Legacy 390.xx branch (for older GPUs)
        '';
      };
    laptop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable dual GPU and PRIME for Nvidia laptops.";
      };
      nvidiaID = mkOption {
        type = types.nullOr types.str;
        default = null; # Default to empty, can be set to specific GPU ID if needed
        description = "The NVIDIA GPU ID for PRIME configurations on laptops.";
      };
      intelBusID = mkOption {
        type = types.nullOr types.str;
        default = null; # Default to empty, can be set to specific GPU ID if needed
        description = "The Intel GPU ID for PRIME configurations on laptops.";
      };
      amdgpuID = mkOption {
        type = types.nullOr types.str;
        default = null; # Default to empty, can be set to specific GPU ID if needed
        description = "The AMD GPU ID for PRIME configurations on laptops.";
      };
    };
    # You could add more nvidia options here: powerManagement, openDrivers, etc.
  };

  config = lib.mkIf cfg.enable {
    # Enable proprietary Nvidia drivers
    hardware.nvidia = {
      open = false; # Use proprietary driver
      modesetting.enable = true; # Needed for Wayland
      powerManagement = {
        enable = true; # Recommended
        finegrained = false;
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
      dynamicBoost.enable = false;
    };

    services.xserver.videoDrivers = [ "nvidia" ]; # Ensure X11 & Wayland use Nvidia driver

    # Ensure necessary firmware is available
    hardware.enableRedistributableFirmware = lib.mkDefault true; # Use mkDefault so host config can override to false if needed

    # Allow unfree packages (required for Nvidia drivers)
    nixpkgs.config.allowUnfree = lib.mkDefault true; # Use mkDefault

  };
}
