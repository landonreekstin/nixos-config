# ~/nixos-config/modules/nixos/unstable.nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.customConfig;
in
{
  config = lib.mkMerge [
    # This block is always active. It sets up the overlays.
    {
      nixpkgs.overlays = [
        # Provides `pkgs.unstable` for convenience (e.g., for apps).
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = prev.system;
            config = prev.config;
          };
        })
        # Conditionally replaces the kernel in the top-level pkgs.
        (final: prev: lib.mkIf cfg.hardware.unstable {
          linuxPackages_latest = final.unstable.linuxPackages_latest;
        })
      ];

      # Handles your `packages.unstable-override` list.
      environment.systemPackages = with pkgs;
        lib.lists.forEach cfg.packages.unstable-override (p: unstable.${p});
    }

    # This block is ONLY active when `hardware.unstable` is true.
    (lib.mkIf cfg.hardware.unstable {
      # 1. Set the kernel packages to the `_latest` version.
      #    Our overlay ensures this points to the unstable kernel.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # 2. THE CORRECT FIX: Explicitly set the NVIDIA package.
      #    This overrides the module's default and forces it to use the drivers
      #    from the *currently configured* kernel package set, which we just
      #    set to unstable in the line above. This resolves the evaluation order issue.
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
    })
  ];
}