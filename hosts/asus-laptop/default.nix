# ~/nixos-config/hosts/asus-laptop/default.nix
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{ inputs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus G14 (GA401 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401

    # Hardware-specific configuration generated for this host.
    # We will generate this file in the install script.
    ./hardware-configuration.nix

    # Top level nixos modules import.
    ../../modules/nixos/default.nix

    # Host configuration, one file per domain
    ./system.nix
    ./desktop.nix
    ./hardware.nix
    ./apps.nix
    ./home.nix
    ./networking.nix
    ./homelab.nix
    ./profiles.nix
  ];
}
