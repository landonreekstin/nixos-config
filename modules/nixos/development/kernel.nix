# ~/nixos-config/modules/profiles/development/kernel.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.kernel;

  # Fetch the image creation script from the syzkaller project
  create-image-script = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh";
    sha256 = "sha256-KkCDTT6vN4UWgHflpP4a7W7RdFZLPvhyzKYh10PEP3c=";
  };

  # Helper script to create the Debian image.
  create-guest-image = pkgs.writeShellScriptBin "create-guest-image" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "This script will create a Debian (Bullseye) disk image for QEMU."
    echo "It uses debootstrap and requires root privileges to run."
    echo "Please ensure you have an internet connection."
    echo "--------------------------------------------------------------------"

    if [[ "$EUID" -ne 0 ]]; then
      if command -v sudo &> /dev/null; then
        echo "Re-executing with sudo..."
        exec sudo /usr/bin/env bash "$0" "$@"
      else
        echo "ERROR: This script must be run as root, and sudo is not found." >&2
        exit 1
      fi
    fi
    
    ORIGINAL_USER=''${SUDO_USER:-$(logname)}
    cp ${create-image-script} ./create-image.sh
    chmod +x ./create-image.sh
    
    echo "Running the syzkaller create-image.sh script to build Debian (bullseye)..."
    ./create-image.sh --distribution bullseye
    
    rm ./create-image.sh
    
    echo ""
    echo "--------------------------------------------------------------------"
    echo "Image 'bullseye.img' and key 'bullseye.id_rsa.pub' created successfully."
    echo "Changing ownership to user: $ORIGINAL_USER"
    
    chown "$ORIGINAL_USER" bullseye.img
    chown "$ORIGINAL_USER" bullseye.id_rsa
    chown "$ORIGINAL_USER" bullseye.id_rsa.pub

    echo "Setup complete."
  '';

  # Script to run the compiled kernel in QEMU
  run-lkp-qemu = pkgs.writeShellScriptBin "run-lkp-qemu" ''
    #!/usr/bin/env bash
    set -euo pipefail

    KERNEL_IMAGE_PATH="./arch/x86/boot/bzImage"
    GUEST_DISK_IMAGE="./bullseye.img"
    MEMORY="4G"
    SSH_PORT_FWD="user,id=net0,hostfwd=tcp::10022-:22"

    if [[ ! -f "''${KERNEL_IMAGE_PATH}" ]]; then
      echo "ERROR: Kernel image not found at ''${KERNEL_IMAGE_PATH}" >&2
      exit 1
    fi

    if [[ ! -f "''${GUEST_DISK_IMAGE}" ]]; then
      echo "ERROR: Guest disk image not found at ''${GUEST_DISK_IMAGE}" >&2
      echo "Hint: Have you run 'create-guest-image' in this directory?" >&2
      exit 1
    fi

    echo "Booting kernel: ''${KERNEL_IMAGE_PATH}"
    echo "Using disk image: ''${GUEST_DISK_IMAGE}"
    echo "----------------------------------------------------"
    echo "Starting QEMU. GDB can connect on port 1234."
    echo "SSH access to the guest will be available on localhost:10022"
    echo "----------------------------------------------------"

    qemu-system-x86_64 \
      -enable-kvm -cpu host -m ''${MEMORY} \
      -kernel "''${KERNEL_IMAGE_PATH}" \
      -hda "''${GUEST_DISK_IMAGE}" \
      -append "root=/dev/sda console=ttyS0" \
      -netdev ''${SSH_PORT_FWD} -device virtio-net-pci,netdev=net0 \
      -nographic \
      -s -S
  '';

  # Script to run GDB and connect to the QEMU session
  run-lkp-gdb = pkgs.writeShellScriptBin "run-lkp-gdb" ''
    #!/usr/bin/env bash
    set -euo pipefail

    KERNEL_ELF_PATH="./vmlinux"

    if [[ ! -f "''${KERNEL_ELF_PATH}" ]]; then
      echo "ERROR: Kernel ELF file not found at ''${KERNEL_ELF_PATH}" >&2
      echo "Hint: This file contains the debug symbols. Did 'make' complete successfully?" >&2
      exit 1
    fi
    
    GDB_AUTO_LOAD_CMD="add-auto-load-safe-path ./scripts/gdb/vmlinux-gdb.py"

    echo "Launching GDB for kernel: ''${KERNEL_ELF_PATH}"
    echo "Connecting to QEMU on tcp::1234"
    echo "----------------------------------------------------"

    gdb -ex "''${GDB_AUTO_LOAD_CMD}" -ex "target remote :1234" "''${KERNEL_ELF_PATH}"
  '';

in
{
  # === MODULE OPTIONS ===
  options.customConfig.profiles.development.kernel.devShell = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    description = "The attribute set for the kernel development shell.";
  };

  # === MODULE CONFIGURATION ===
  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.kernel.devShell = {
      buildInputs = with pkgs; [
        # Core Build Tools
        git gnumake gcc ncurses bc binutils flex bison elfutils openssl util-linux pkg-config
        qemu_kvm debootstrap gdb clang clang-tools lld llvm
        cppcheck cscope curl fakeroot flawfinder indent sparse
        gnuplot hwloc numad man-db numactl psmisc python3 perl pahole rt-tests
        smem stress sysfsutils trace-cmd tree tuna virt-what zlib tldr
        
        # === Our Custom Helper Scripts ===
        create-guest-image
        run-lkp-qemu
        run-lkp-gdb
      ];

      shellHook = ''
        echo "Entered Linux Kernel Development Shell."
        echo "------------------------------------"
        echo "To create the guest image, run: create-guest-image"
        echo "To run your compiled kernel, run: run-lkp-qemu"
        echo "In a second terminal, run:      run-lkp-gdb"
        echo "------------------------------------"
      '';
    };
  };
}