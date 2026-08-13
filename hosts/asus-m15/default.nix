# ~/nixos-config/hosts/asus-m15/default.nix
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{ inputs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus M15 (GA502 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-gu603h

    # Hardware-specific configuration generated for this host.
    # We will generate this file in the install script.
    ./hardware-configuration.nix

    ./disko-config.nix

    # Top level nixos modules import.
    ../../modules/nixos/default.nix

    # Host configuration, one file per domain
    ./system.nix
    ./desktop.nix
    ./hardware.nix
    ./apps.nix
    ./home.nix
    ./networking.nix
    ./profiles.nix
  ];
}
