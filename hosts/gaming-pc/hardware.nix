# ~/nixos-config/hosts/gaming-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false;
    nvidia = {
      enable = true;
    };
    peripherals = {
      enable = true; # Enable peripheral configurations
      ckb-next = {
        enable = true;
        # Color/brightness managed at runtime via ~/.cache/ckb-color-state
      };
    };
    bluetooth = {
      waybar.enable = true;
    };
    monitors = [
      { name = "DP-1";     rotation = "Normal";    scale = 1.15; } # Main: LG 2560x1440 @ 180Hz
      { name = "HDMI-A-1"; rotation = "Rotated90"; }               # Left: Dell 1080p portrait
      { name = "DP-2";     rotation = "Rotated90"; }               # Right: Samsung 1080p portrait
      { name = "DP-3";     rotation = "Normal"; }                  # Above: Hisense TV 1080p
    ];
  };

  # RTX 4070 Ti Super (Ada Lovelace): open kernel modules recommended for Turing+ with driver 560+.
  # The shared nvidia.nix sets open=false as a safe default; override it here for this host.
  hardware.nvidia.open = lib.mkForce true;

  # Load NVIDIA modules in the initrd for early KMS so Plymouth can render during boot.
  # Without this, Plymouth starts before NVIDIA loads and finds no framebuffer (simpledrm
  # is blacklisted), resulting in a black screen instead of the splash animation.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # Blacklist the Realtek RTW8852CE wireless driver.
  # The rtw89_8852ce firmware crashes periodically (SER errors), causing a brief
  # PCIe bus stall that makes the wired NIC (r8169/enp8s0) temporarily unreachable too.
  # Gaming-pc is a desktop with wired Ethernet — Wi-Fi is not needed.
  boot.blacklistedKernelModules = [ "rtw89_8852ce" "rtw89_8852c" "rtw89pci" "rtw89core" ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wifi-enable" ''
      exec sudo modprobe rtw89_8852ce
    '')
  ];
}
