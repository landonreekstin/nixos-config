# ~/nixos-config/hosts/optiplex/default.nix
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{ ... }:

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    # Declarative disk partitioning layout (used by install-new-host.sh)
    ./disko-config.nix
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
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
