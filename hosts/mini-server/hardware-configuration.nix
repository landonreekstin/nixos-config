# ~/nixos-config/hosts/mini-server/hardware-configuration.nix
# PLACEHOLDER — replace with `nixos-generate-config` output on first NixOS install.
# Do NOT commit the real hardware-configuration.nix until disko fileSystems are stripped from it
# (disko generates fileSystems; having both causes conflicts at eval time).
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # BeeLink AZW Mini S: Intel N95 (Alder Lake-N), NVMe SSD, USB peripherals
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [];

  swapDevices = [];
}
