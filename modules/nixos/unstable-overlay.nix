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
            system = prev.system;
            config = prev.config;
          };
        })
        # Conditionally replaces the kernel.
        (final: prev: lib.mkIf cfg.hardware.unstable {
          linuxPackages_latest = final.unstable.linuxPackages_latest;
        })
      ];

      # Handles the `unstable-override` package list.
      environment.systemPackages = with pkgs;
        lib.lists.forEach cfg.packages.unstable-override (p: unstable.${p});
    }

    # This block is only active when the unstable hardware flag is true.
    (lib.mkIf cfg.hardware.unstable {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      hardware.nvidia.package = pkgs.unstable.linuxPackages_latest.nvidiaPackages.latest;
    })
  ];
}