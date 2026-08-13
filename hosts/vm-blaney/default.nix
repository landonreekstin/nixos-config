# ~/nixos-config/hosts/vm-blaney/default.nix
{ ... }:

# blaney-pc software mirror — a throwaway QEMU VM that reproduces blaney-pc's KDE/aerotheme
# + Hyprland + XFCE(windows7) software configuration so his theme/plasma/taskbar can be
# reproduced and reviewed locally on gaming-pc before pushing a `blaney/` PR to that machine.
#
# Mirrors the *software* surface faithfully, INCLUDING his XFCE windows7 taskbar (exact
# xfcePanel pins) + the apps those pins reference (gaming profile for Steam/Heroic/Lutris;
# peripheral GUIs added directly since vm-common force-disables the hardware peripherals;
# flatpaks for Chromium/Discord/Spotify) so the taskbar renders with real icons for a pre-PR
# visual check. Hardware/boot bits are still dropped: no hardware-configuration.nix, no
# plymouth, nvidia + peripherals forced off (VM has no GPU/devices → llvmpipe). NOTE the VM
# can't reproduce the NVIDIA-open kwin-wayland breakage (that's real-hardware only); pick the
# "Xfce Session" at Ly to review the taskbar.
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
