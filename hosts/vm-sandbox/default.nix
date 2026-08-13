# ~/nixos-config/hosts/vm-sandbox/default.nix
{ ... }:

# Kitchen-sink ricing sandbox — a throwaway QEMU VM that turns on the fragile paradigms
# (aerothemeplasma KDE + Hyprland/century-series + browser/app config) all at once, so
# desktop/theme/app work can be iterated without touching gaming-pc. See ../vm-common.nix
# for VM sizing, guest tooling, and the nvidia/peripherals force-off.
#
# Importer only — this host's settings live in the per-domain files below, mirroring
# the layout of modules/nixos/.
{
  imports = [
    ../../modules/nixos/default.nix
    ../vm-common.nix

    # Host configuration, one file per domain
    ./system.nix
    ./desktop.nix
    ./apps.nix
    ./home.nix
    ./networking.nix
    ./profiles.nix
  ];
}
