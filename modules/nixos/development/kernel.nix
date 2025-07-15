# ~/nixos-config/modules/profiles/development/kernel.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.kernel;

  guest-kernel-config-fragment = ./kernel-files/guest_kernel.config;

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

    echo "--- Post-processing guest image for networking and SSH..."
    MOUNT_DIR=$(mktemp -d)
    trap 'umount "''${MOUNT_DIR}" &>/dev/null || true; rmdir "''${MOUNT_DIR}"' EXIT

    mount ./bullseye.img "''${MOUNT_DIR}"

    # 1. Configure systemd-networkd for automatic DHCP
    cat <<EOF > "''${MOUNT_DIR}/etc/systemd/network/20-wired.network"
[Match]
Name=enp0s3

[Network]
DHCP=yes
EOF

    # 2. Enable the systemd-networkd service
    ln -sf /lib/systemd/system/systemd-networkd.service "''${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
    
    # 3. Ensure the legacy networking service is disabled by removing its symlinks
    rm -f "''${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/networking.service"
    rm -f "''${MOUNT_DIR}/etc/systemd/system/network-online.target.wants/networking.service"

    echo "--- Post-processing complete. Unmounting image..."
    # The trap will handle the unmount and cleanup
    
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

  configure-guest-kernel = pkgs.writeShellScriptBin "configure-guest-kernel" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -f "Kconfig" ] || [ ! -d "scripts" ]; then
        echo "ERROR: This does not look like a kernel source directory." >&2
        echo "Please run this from the root of the kernel source tree." >&2
        exit 1
    fi

    echo "--- Creating a clean 'defconfig' as a baseline..."
    make defconfig

    echo "--- Merging the NixOS guest configuration fragment..."
    ./scripts/kconfig/merge_config.sh -m .config ${guest-kernel-config-fragment}

    echo "--- Applying new defaults from the merged configuration..."
    make olddefconfig

    echo ""
    echo "Configuration complete."
    echo "You can now run 'make menuconfig' to make further changes,"
    echo "or run 'make' to start building the kernel."
  '';

  # Script to run the compiled kernel in QEMU
  qemu-run = pkgs.writeShellScriptBin "qemu-run" ''
    #!/usr/bin/env bash
    set -euo pipefail

    KERNEL_IMAGE_PATH="./arch/x86/boot/bzImage"
    GUEST_DISK_IMAGE="./bullseye.img"
    MEMORY="4G"
    SSH_PORT_FWD="user,id=net0,hostfwd=tcp::10022-:22"
    INITRD_PATH="./initrd.img-5.10.0-28-amd64"

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
  gdb-run = pkgs.writeShellScriptBin "gdb-run" ''
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

  extract-guest-initrd = pkgs.writeShellScriptBin "extract-guest-initrd" ''
    #!/usr/bin/env bash
    set -euo pipefail

    GUEST_IMAGE="./bullseye.img"
    MOUNT_DIR=$(mktemp -d) # Create a secure temporary mount point

    # Ensure we always attempt to unmount and remove the temp directory
    trap 'sudo umount "''${MOUNT_DIR}" &>/dev/null || true; rm -rf "''${MOUNT_DIR}"' EXIT

    if [[ ! -f "''${GUEST_IMAGE}" ]]; then
      echo "ERROR: Guest image not found at ''${GUEST_IMAGE}" >&2
      exit 1
    fi

    echo "Mounting ''${GUEST_IMAGE} at ''${MOUNT_DIR}..."
    sudo mount "''${GUEST_IMAGE}" "''${MOUNT_DIR}"

    # Find the latest initrd image file in the guest's /boot directory
    INITRD_GUEST_PATH=$(ls -v "''${MOUNT_DIR}"/boot/initrd.img-* | tail -n 1)

    if [[ -z "''${INITRD_GUEST_PATH}" ]]; then
        echo "ERROR: Could not find an initrd.img-* file in the guest's /boot directory." >&2
        exit 1
    fi

    INITRD_FILENAME=$(basename "''${INITRD_GUEST_PATH}")
    echo "Found initrd: ''${INITRD_FILENAME}'. Copying to current directory..."
    sudo cp "''${INITRD_GUEST_PATH}" "./''${INITRD_FILENAME}"

    echo "Changing ownership to current user..."
    sudo chown "''${SUDO_USER:-$(whoami)}" "./''${INITRD_FILENAME}"

    echo "Successfully extracted ''${INITRD_FILENAME}."
  '';

  load-module = pkgs.writeShellScriptBin "load-module" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ -z "$1" ]]; then
      echo "Usage: $0 <path_to_module.ko>"
      exit 1
    fi

    MODULE_PATH="$1"
    if [[ ! -f "''${MODULE_PATH}" ]]; then
        echo "ERROR: Module file not found at ''${MODULE_PATH}" >&2
        exit 1
    fi

    SSH_PORT="10022"
    SSH_USER="root"
    SSH_HOST="localhost"
    SSH_KEY="./bullseye.id_rsa"
    MOD_NAME=$(basename "''${MODULE_PATH}")
    GUEST_TMP_PATH="/tmp/''${MOD_NAME}"

    # Common SSH/SCP options for passwordless, non-interactive use
    SSH_OPTS="-i ''${SSH_KEY} -p ''${SSH_PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    if [[ ! -f "''${SSH_KEY}" ]]; then
        echo "ERROR: SSH key not found at ''${SSH_KEY}". >&2
        echo "Hint: Did you run 'create-guest-image' in this directory?" >&2
        exit 1
    fi

    echo "--- Copying ''${MOD_NAME} to guest..."
    scp ''${SSH_OPTS} "''${MODULE_PATH}" "''${SSH_USER}@''${SSH_HOST}":"''${GUEST_TMP_PATH}"

    echo "--- Loading module in guest..."
    ssh ''${SSH_OPTS} "''${SSH_USER}@''${SSH_HOST}" "insmod ''${GUEST_TMP_PATH}"

    echo "--- Recent kernel messages from guest:"
    ssh ''${SSH_OPTS} "''${SSH_USER}@''${SSH_HOST}" "dmesg | tail -n 15"
    
    echo "--- Cleaning up module from guest..."
    ssh ''${SSH_OPTS} "''${SSH_USER}@''${SSH_HOST}" "rm ''${GUEST_TMP_PATH}"

    echo "--- Done."
  '';

  ssh-guest = pkgs.writeShellScriptBin "ssh-guest" ''
    #!/usr/bin/env bash
    set -euo pipefail
    SSH_KEY="./bullseye.id_rsa"
    if [[ ! -f "''${SSH_KEY}" ]]; then
        echo "ERROR: SSH key not found at ''${SSH_KEY}" >&2
        exit 1
    fi
    echo "--- Connecting to guest VM. Use 'exit' to return. ---"
    ssh -i "''${SSH_KEY}" root@localhost -p 10022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
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
        configure-guest-kernel
        qemu-run
        gdb-run
        ssh-guest
        extract-guest-initrd
        load-module
      ];

      shellHook = ''
        echo "Entered Linux Kernel Development Shell."
        echo "------------------------------------"
        echo "cd to your kernel source directory before running commands."
        echo "To configure your kernel: configure-guest-kernel"
        echo "To build your kernel:     make -j$(nproc)"
        echo "To run your compiled kernel, run: run-lkp-qemu"
        echo "In a second terminal, run:      run-lkp-gdb"
        echo "To SSH into the guest VM: ssh-guest"
        echo "To load a kernel module:  load-module ./path/to/module.ko"
        echo ""
        echo "Guest Image Management:"
        echo "To create a new image:    create-guest-image"
        echo "To extract its initrd:    extract-guest-initrd"
        echo "------------------------------------"
      '';
    };
  };
}