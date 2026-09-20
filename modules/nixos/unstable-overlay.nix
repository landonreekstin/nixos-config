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
            overlays = [ ];
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

        # --- signal-desktop version floor ---
        # Signal's on-disk database only moves forward: opening it with a newer
        # release migrates ~/.config/Signal to a higher schema, and older builds
        # then refuse to start ("The version of your database does not match this
        # version of Signal"). Nothing downgrades the database back.
        #
        # That makes signal-desktop uniquely hostile to this repo's branch churn.
        # gaming-pc hit it on 2026-09-14: the update/* branch it was soaking as
        # betaTesterHost disappeared from origin, `update` correctly fell back to
        # main, and main's older nixpkgs-unstable pin took signal 8.25.0 -> 8.21.0
        # while the database sat at schema 1770 (8.21.0 tops out at 1740).
        #
        # So this overlay is a floor, not a pin: whatever the current branch
        # offers wins as long as it is at least as new as inputs.nixpkgs-signal.
        # Signal keeps tracking channel updates normally — it just cannot be
        # dragged below a version that has already touched a database here.
        # Must come after the unstable-override overlay to win the ordering.
        (final: prev:
          let
            pinned = (import inputs.nixpkgs-signal {
              system = prev.stdenv.hostPlatform.system;
              config = prev.config;
              overlays = [ ];
            }).signal-desktop;
          in {
            signal-desktop =
              if lib.versionAtLeast prev.signal-desktop.version pinned.version
              then prev.signal-desktop
              else pinned;
          })
      ];
    }

    # This block is only active when the unstable hardware flag is true.
    (lib.mkIf cfg.hardware.unstable {
      # mkDefault so individual hosts can pin to a specific kernel without mkForce.
      # Only hosts with hardware.unstable = true reach this block; they get linuxPackages_latest
      # from nixpkgs-unstable (see kernel overlay above). Older-hardware hosts should set
      # hardware.unstable = false to stay on the stable channel's LTS kernel instead.
      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.${cfg.hardware.nvidia.package};
    })
  ];
}
