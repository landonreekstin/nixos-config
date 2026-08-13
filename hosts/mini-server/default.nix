# ~/nixos-config/hosts/mini-server/default.nix
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/default.nix
    ./disko-config.nix

    # Host configuration, one file per domain
    ./system.nix
    ./desktop.nix
    ./apps.nix
    ./home.nix
    ./networking.nix
    ./homelab.nix
    ./profiles.nix
  ];
}
