# ~/nixos-config/modules/nixos/unstable.nix

# This file is now a FUNCTION that takes 'inputs' as an argument...
inputs:

# ...and RETURNS a standard NixOS module.
{ config, lib, pkgs, ... }:

let
  # It reads its configuration from the host's customConfig, as intended.
  cfg = config.customConfig;
in
{
  # We use lib.mkMerge to combine multiple configurations cleanly.
  config = lib.mkMerge [
    # This block is always active to provide the overlays.
    {
      nixpkgs.overlays = [
        # Provides `pkgs.unstable`. We can use 'inputs' here because it was
        # passed as an argument to the entire file.
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = prev.stdenv.hostPlatform.system;
            config = prev.config;
            overlays = [
              # electron_39 (39.8.2) has a broken nixpkgs patch — heroic depends on it.
              # Re-check after a flake update: if heroic no longer pulls electron_39 this can be removed.
              (selfU: superU: {
                electron_39 = superU.electron_40;
              })
            ];
          };
        })
        # Conditionally replaces the kernel.
        (final: prev: if cfg.hardware.unstable then {
          linuxPackages_latest = final.unstable.linuxPackages_latest;
        } else {})

        # --- The Simplified Package Override Overlay ---
        (final: prev:
          # `genAttrs` builds an attribute set from our single list.
          # For each package name in the list, it creates an entry that
          # points the stable name to the unstable version.
          lib.genAttrs cfg.packages.unstable-override (p: final.unstable.${p})
        )
      ];
    }

    # This block is only active when the unstable hardware flag is true.
    (lib.mkIf cfg.hardware.unstable {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.${cfg.hardware.nvidia.package};
    })
  ];
}