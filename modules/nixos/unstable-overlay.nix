# ~/nixos-config/modules/nixos/unstable-overlay.nix
{ config, lib, unstablePkgs, ... }:

with lib;

let
  # Get the host-specific list of unstable packages from our custom option
  unstablePackages = config.customConfig.packages.unstable-override;
in
{
  # This is where we add the overlay to the main nixpkgs config
  nixpkgs.overlays = [
    (final: prev: {
      # --- Main Overlay Logic ---
      # This function takes the list of package names (strings) and for each one,
      # assigns the unstable package (prev.unstable.${pkgName}) to the final
      # package set.
      unstable = unstablePkgs; # Recommended: Make the full unstable set available as pkgs.unstable
    } // # The `//` operator merges the two attribute sets
    (listToAttrs (map (
        pkgName: {
          name = pkgName;
          value = unstablePkgs.${pkgName};
        }
      ) unstablePackages))
    )
  ];
}