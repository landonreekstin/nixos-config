# ~/nixos-config/modules/profiles/development/kernel.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.kernel;

  guest-kernel-config-fragment = ./kernel-files/guest_kernel.config;

  c_cpp_template = ./kernel-files/c_cpp_properties.json.template;

  create-image-script = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh";
    sha256 = "sha256-KkCDTT6vN4UWgHflpP4a7W7RdFZLPvhyzKYh10PEP3c=";
  };

  create-guest-image = pkgs.writeShellScriptBin "create-guest-image" ''
    #!/usr/bin/env bash
    set -euo pipefail
    cd "''${LKP_GUEST_PATH}"
    echo "This script will create a Debian (Bullseye) disk image in ''${LKP_GUEST_PATH}"
    if [[ "$EUID" -ne 0 ]]; then exec sudo /usr/bin/env bash "$0" "$@"; fi
    ORIGINAL_USER=''${SUDO_USER:-$(logname)}
    cp ${create-image-script} ./create-image.sh && chmod +x ./create-image.sh
    echo "--- Running the syzkaller create-image.sh script..."
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

    # 2. Enable the systemd-networkd service and disable the legacy one
    ln -sf /lib/systemd/system/systemd-networkd.service "''${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
    rm -f "''${MOUNT_DIR}/etc/systemd/system/multi-user.target.wants/networking.service"
    rm -f "''${MOUNT_DIR}/etc/systemd/system/network-online.target.wants/networking.service"
    rm ./create-image.sh
    chown "$ORIGINAL_USER" bullseye.img bullseye.id_rsa bullseye.id_rsa.pub

    echo "Setup complete. Guest image is in ''${LKP_GUEST_PATH}"
  '';

  configure-guest-kernel = pkgs.writeShellScriptBin "configure-guest-kernel" ''
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "Kconfig" ]; then
        echo "ERROR: Must be run from the root of a kernel source tree." >&2
        exit 1
    fi
    echo "--- Creating a clean 'defconfig' as a baseline..."
    make defconfig
    echo "--- Merging the NixOS guest configuration fragment..."
    ./scripts/kconfig/merge_config.sh -m .config ${guest-kernel-config-fragment}
    echo "--- Applying new defaults from the merged configuration..."
    make olddefconfig
    echo "Configuration complete."
  '';

  qemu-run = pkgs.writeShellScriptBin "qemu-run" ''
    #!/usr/bin/env bash
    set -euo pipefail
    KERNEL_IMAGE_PATH="./arch/x86/boot/bzImage"
    GUEST_DISK_IMAGE="''${LKP_GUEST_PATH}/bullseye.img" # Use absolute path

    if [[ ! -f "''${KERNEL_IMAGE_PATH}" ]]; then
      echo "ERROR: Kernel image not found at ''${KERNEL_IMAGE_PATH}" >&2
      exit 1
    fi
    if [[ ! -f "''${GUEST_DISK_IMAGE}" ]]; then
      echo "ERROR: Guest disk image not found at ''${GUEST_DISK_IMAGE}" >&2
      exit 1
    fi
    echo "--- Starting QEMU. GDB can connect on port 1234."
    qemu-system-x86_64 \
      -enable-kvm -cpu host -m 4G \
      -kernel "''${KERNEL_IMAGE_PATH}" \
      -hda "''${GUEST_DISK_IMAGE}" \
      -append "root=/dev/sda console=ttyS0" \
      -netdev user,id=net0,hostfwd=tcp::10022-:22 -device virtio-net-pci,netdev=net0 \
      -nographic -s -S
  '';

  gdb-run = pkgs.writeShellScriptBin "gdb-run" ''
    #!/usr/bin/env bash
    set -euo pipefail
    KERNEL_ELF_PATH="./vmlinux"
    if [[ ! -f "''${KERNEL_ELF_PATH}" ]]; then
      echo "ERROR: Kernel ELF file not found at ''${KERNEL_ELF_PATH}" >&2
      exit 1
    fi
    gdb -ex "add-auto-load-safe-path ./scripts/gdb/vmlinux-gdb.py" -ex "target remote :1234" "''${KERNEL_ELF_PATH}"
  '';
  
  ssh-guest = pkgs.writeShellScriptBin "ssh-guest" ''
    #!/usr/bin/env bash
    set -euo pipefail
    SSH_KEY="''${LKP_GUEST_PATH}/bullseye.id_rsa"
    if [[ ! -f "''${SSH_KEY}" ]]; then echo "ERROR: SSH key not found at ''${SSH_KEY}" >&2; exit 1; fi
    ssh -i "''${SSH_KEY}" -p 10022 root@localhost -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
  '';

  load-module = pkgs.writeShellScriptBin "load-module" ''
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "$1" ]]; then echo "Usage: $0 <path_to_module.ko>"; exit 1; fi
    MODULE_PATH="$1"
    if [[ ! -f "''${MODULE_PATH}" ]]; then echo "ERROR: Module file not found" >&2; exit 1; fi
    SSH_KEY="''${LKP_GUEST_PATH}/bullseye.id_rsa"
    if [[ ! -f "''${SSH_KEY}" ]]; then echo "ERROR: SSH key not found" >&2; exit 1; fi
    
    MOD_NAME=$(basename "''${MODULE_PATH}")
    GUEST_TMP_PATH="/tmp/''${MOD_NAME}"
    
    # CORRECTED: Use uppercase -P for scp
    SCP_OPTS="-i ''${SSH_KEY} -P 10022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    SSH_OPTS="-i ''${SSH_KEY} -p 10022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    echo "--- Copying ''${MOD_NAME} to guest..."
    scp ''${SCP_OPTS} "''${MODULE_PATH}" "root@localhost":"''${GUEST_TMP_PATH}"
    echo "--- Loading module in guest..."
    ssh ''${SSH_OPTS} "root@localhost" "insmod ''${GUEST_TMP_PATH}"
    echo "--- Recent kernel messages from guest:"
    ssh ''${SSH_OPTS} "root@localhost" "dmesg | tail -n 15"
    echo "--- Cleaning up module from guest..."
    ssh ''${SSH_OPTS} "root@localhost" "rm ''${GUEST_TMP_PATH}"
    echo "--- Done."
  '';
  
    lkm-run = pkgs.writeShellScriptBin "lkm-run" ''
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "$1" ]]; then
      echo "Usage: $0 <module_name_without_extension>"
      exit 1
    fi
    if [[ -z "''${LKP_KSRC}" ]]; then
        echo "ERROR: LKP_KSRC environment variable is not set." >&2
        echo "Hint: Did you 'cd' into a specific kernel source directory first?" >&2
        exit 1
    fi

    MOD_NAME="$1"

    echo "--- Building module ''${MOD_NAME}.ko on host using kernel from ''${LKP_KSRC}..."
    # This now overrides the KDIR in any of Kaiwan's Makefiles
    make KDIR="''${LKP_KSRC}"

    if [[ ! -f "''${MOD_NAME}.ko" ]]; then
        echo "ERROR: Build failed. ''${MOD_NAME}.ko not found." >&2
        exit 1
    fi
    echo "--- Preparing guest VM..."
    ssh-guest "rmmod ''${MOD_NAME}" || true
    ssh-guest "dmesg -C"
    echo "--- Loading module into guest..."
    load-module "./''${MOD_NAME}.ko"
    echo "--- LKM run complete."
  '';

  shutdown-guest = pkgs.writeShellScriptBin "shutdown-guest" ''
    #!/usr/bin/env bash
    set -euo pipefail

    QEMU_PROCESS_PATTERN="qemu-system-x86_64.*bullseye.img"

    # 1. Check if the VM process exists
    if ! pgrep -f "$QEMU_PROCESS_PATTERN" > /dev/null; then
        echo "Guest VM does not appear to be running."
        exit 0
    fi

    echo "--- Attempting a graceful shutdown via SSH..."
    
    # 2. Try to send the poweroff command with a 5-second timeout.
    # We add '|| true' because 'timeout' will exit with a non-zero code on timeout,
    # and we want to handle that failure case ourselves.
    EXIT_CODE=0
    timeout 5 ssh-guest "poweroff" || EXIT_CODE=$?

    # 3. Check the result
    if [ $EXIT_CODE -eq 0 ]; then
        echo "Shutdown command sent successfully. The guest VM is powering off."
        # Wait a moment for the process to terminate
        sleep 2
        # Check again
        if ! pgrep -f "$QEMU_PROCESS_PATTERN" > /dev/null; then
            echo "VM has shut down."
            exit 0
        fi
    elif [ $EXIT_CODE -eq 124 ]; then
        echo "[!] Graceful shutdown timed out."
        echo "    This usually means GDB has the VM frozen."
        echo "    Hint: Go to your gdb-run terminal and type 'detach' first."
    else
        echo "[!] Graceful shutdown failed with an unexpected error (code: $EXIT_CODE)."
    fi

    # 4. Offer a forceful shutdown if the graceful one failed
    echo ""
    read -p "Forcefully kill the QEMU process? (y/N) " -n 1 -r
    echo "" # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "--- Forcefully killing the QEMU process..."
        pkill -f "$QEMU_PROCESS_PATTERN"
        echo "Process killed."
    else
        echo "Shutdown aborted. The VM is likely still running."
    fi
  '';

  vscode-setup = pkgs.writeShellScriptBin "vscode-setup" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ -z "''${LKP_KSRC}" ]]; then
        echo "ERROR: LKP_KSRC environment variable is not set." >&2
        exit 1
    fi

    echo "--- Generating compile_commands.json with 'bear'..."
    make -k -C "''${LKP_KSRC}" M="$PWD" clean || true
    set +e
    bear -- make -k -C "''${LKP_KSRC}" M="$PWD"
    set -e

    if [[ ! -f "compile_commands.json" ]]; then
        echo "[!] ERROR: Failed to generate compile_commands.json" >&2
        exit 1
    fi

    echo "--- Creating VS Code C/C++ extension configuration from template..."
    mkdir -p .vscode
    
    # This is the new, robust logic:
    # 1. Define the path to the compiler from the Nix variable.
    # 2. Use 'sed' to replace the placeholder in the template file.
    # 3. Save the result to the final destination.
    GCC_PATH="${pkgs.gcc}/bin/gcc"
    sed "s|__GCC_PATH_PLACEHOLDER__|''${GCC_PATH}|" "${c_cpp_template}" > .vscode/c_cpp_properties.json

    echo ""
    echo "--- VS Code setup complete! ---"
    echo "Please reload the VS Code window (Ctrl+Shift+P -> 'Developer: Reload Window')"
    echo "to activate the new IntelliSense configuration."
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
        git gnumake gcc ncurses bc binutils flex bison elfutils openssl util-linux pkg-config
        qemu_kvm debootstrap gdb clang clang-tools lld llvm
        cppcheck cscope curl fakeroot flawfinder indent sparse
        gnuplot hwloc numad man-db numactl psmisc python3 perl pahole rt-tests
        smem stress sysfsutils trace-cmd tree tuna virt-what zlib tldr
        bear
        create-guest-image
        configure-guest-kernel
        qemu-run
        gdb-run
        ssh-guest
        lkm-run
        load-module
        shutdown-guest
        vscode-setup
      ];

      shellHook = ''
        export LKP_GUEST_PATH="$HOME/kernel-dev"
        echo "Entered Linux Kernel Development Shell."
        echo "--------------------------------------------------------"
        echo "Guest image path: ''${LKP_GUEST_PATH}"
        echo
        echo "Primary Workflow Commands:"
        echo "  configure-guest-kernel # Run in kernel source dir"
        echo "  make -j$(nproc)         # Run in kernel source dir"
        echo "  qemu-run               # Run in kernel source dir"
        echo "  lkm-run my_module      # Run in module source dir"
        echo "  ssh-guest              # Run anywhere"
        echo "  shutdown-guest         # Run anywhere to stop the VM"
        echo "  vscode-setup           # Run once in your module project root for extra VS Code support"
        echo "--------------------------------------------------------"
      '';
    };
  };
}