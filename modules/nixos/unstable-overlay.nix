# ~/nixos-config/modules/nixos/unstable.nix
{ config, lib, inputs, ... }:

with lib;

# This overlay is the single source of truth for pulling packages from the
# 'nixpkgs-unstable' flake input. It handles both hardware-level overrides
# (like the kernel) and specific application overrides.

let
  # A helper to check if any unstable packages are requested at all.
  unstableNeeded = config.customConfig.hardware.unstable || config.customConfig.packages.unstable-override != [];
in
{
  # Only apply these overlays if they are actually needed.
  config = mkIf unstableNeeded {
    nixpkgs.overlays = [
      (final: prev:
        let
          # 1. Import the unstable package set ONCE, passing the same config
          #    that our main nixpkgs receives. This is crucial for consistency.
          unstablePkgs = import inputs.nixpkgs-unstable {
            system = prev.system;
            config = config.nixpkgs.config;
          };

          # 2. Define hardware-related overrides if the unstable hardware
          #    flag is enabled.
          hardwareOverrides = mkIf config.customConfig.hardware.unstable {
            # This is the key fix: We override 'kernelPackages' at the source.
            # Any part of the system that asks for kernel packages will now
            # automatically receive the unstable version with its correct modules.
            kernelPackages = unstablePkgs.linuxPackages_latest;
          };

          # 3. Define overrides for the specific list of applications.
          #    'genAttrs' creates an attribute set from a list of names.
          #    This correctly overrides 'pkgs.discord-canary' instead of creating
          #    'pkgs.packages.discord-canary'.
          appOverrides = genAttrs config.customConfig.packages.unstable-override (pkgName:
            if (hasAttr pkgName unstablePkgs) then
              unstablePkgs.${pkgName}
            else
              # Provide a helpful error if the package doesn't exist in unstable
              throw "Package '${pkgName}' requested from unstable does not exist in the nixpkgs-unstable channel."
          );

        # 4. Merge the hardware and application overrides.
        #    The '//' operator merges attribute sets; a key in the left set
        #    is replaced by the same key in the right set.
        in
        hardwareOverrides // appOverrides
      )
    ];
  };
}