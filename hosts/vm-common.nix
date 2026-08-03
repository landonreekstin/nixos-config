# ~/nixos-config/hosts/vm-common.nix
{ config, pkgs, lib, ... }:

# Shared guest module for the throwaway QEMU test-VM hosts (vm-sandbox, vm-blaney).
#
# These hosts are never installed to real hardware — they exist to iterate on the
# fragile software-config surface (aerothemeplasma, plasma, Hyprland, app/theme wiring)
# without disrupting gaming-pc or a headless server. Launch with:
#
#   nixos-rebuild build-vm --flake /home/lando/nixos-config#vm-sandbox --impure
#   ./result/bin/run-*-vm
#
# NOTE: a VM cannot validate GPU/driver behaviour (NVIDIA KMS, TTY framebuffer). QEMU
# falls back to llvmpipe software rendering, so nvidia + peripherals are forced OFF here.
{
  # --- Boot / filesystem stub -------------------------------------------------
  # No generated hardware-configuration.nix exists for these hosts. The common
  # bootloader module already sets systemd-boot; we only need to declare a root (and
  # ESP) filesystem so `system.build.toplevel` evaluates and builds for CI. When
  # launched via `build-vm`, the qemu-vm module (mkVMOverride) replaces the root fs
  # with the VM's synthetic disk, so these entries are inert for the running VM.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # --- VM sizing / display ----------------------------------------------------
  # The qemu-vm options (memorySize/cores/resolution/qemu.*) only exist inside the
  # `vmVariant` sub-evaluation — the module isn't in the base set — so they must be
  # nested here. This block applies only when building `…build.vm`; the plain toplevel
  # (CI) is unaffected.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 16384;  # MiB — gaming-pc has 64G; Plasma under llvmpipe likes headroom
    cores = 12;          # llvmpipe rendering is CPU-bound — more vCPUs = much smoother
    diskSize = 20480;    # MiB throwaway qcow2
    resolution = { x = 1920; y = 1080; };
    # Host-GPU-accelerated GL via virgl: virtio-vga-gl + a GTK display with gl=on offloads
    # the guest's OpenGL to gaming-pc's real GPU instead of llvmpipe software rendering —
    # a big smoothness jump for Plasma/Hyprland compositing. Needs a host GL stack (fine on
    # gaming-pc). If a host ever shows a black window, fall back to `[ "-vga virtio" ]`.
    # grab-on-hover=on: QEMU grabs the keyboard (incl. Super/Meta) while focused, via the
    # Wayland keyboard-shortcuts-inhibit protocol — otherwise a Wayland host compositor
    # (Hyprland/KWin) eats Meta+* binds before they reach the guest, making Super-based
    # keybinds untestable. Press Ctrl+Alt+G in the window to force the grab on/off.
    qemu.options = [ "-vga none" "-device virtio-vga-gl" "-display gtk,gl=on,grab-on-hover=on" ];
  };

  # --- Guest integration ------------------------------------------------------
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  environment.systemPackages = [ pkgs.spice-vdagent ];

  # --- Headless debug access --------------------------------------------------
  # Turn on the repo's own ssh module rather than hand-rolling openssh here: it already
  # installs lando's public keys (users-groups.nix gates them on this same flag), so the
  # VMs get key-based login with no passwords in the guest. The host hosts set
  # services.ssh.enable = false, hence mkForce.
  #
  # This is what makes a black/blank guest display debuggable: ssh in on port 2222 and
  # read the session journal instead of guessing at a dark window.
  #   ssh -p 2222 insideabush@127.0.0.1
  customConfig.services.ssh.enable = lib.mkForce true;

  # Throwaway VMs — don't stop to ask for a sudo password while debugging.
  security.sudo.wheelNeedsPassword = false;

  virtualisation.vmVariant.virtualisation.forwardPorts = [
    {
      from = "host";
      host = {
        address = "127.0.0.1";
        port = 2222;
      };
      guest.port = 22;
    }
  ];

  # --- Force hardware OFF -----------------------------------------------------
  # The VM has no GPU and no peripherals. Forcing these off also keeps the openrazer
  # out-of-tree kernel module out of the VM runtime — its *build* coverage still comes
  # for free from building the real blaney-pc / optiplex toplevels in CI.
  customConfig.hardware.nvidia.enable = lib.mkForce false;
  customConfig.hardware.peripherals.enable = lib.mkForce false;

  # --- Convenience ------------------------------------------------------------
  # Autologin the VM user when the host uses SDDM (ly has its own login flow — those
  # hosts log in manually with the initialPassword set in the host config).
  services.displayManager.autoLogin =
    lib.mkIf (config.customConfig.desktop.displayManager.type == "sddm") {
      enable = true;
      user = config.customConfig.user.name;
    };
}
