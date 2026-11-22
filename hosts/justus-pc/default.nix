# ~/nixos-config/hosts/justus-pc/default.nix
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{ inputs, ... }:

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix

    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    # The shared module library (this repo for now; the library flake once split).
    "${inputs.self}/modules/nixos/default.nix"

    # Host specific disk configuration
    ./disko-config.nix

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
