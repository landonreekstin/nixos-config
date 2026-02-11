# ~/nixos-config/modules/nixos/development/embedded-linux.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.embedded-linux;

  # Helper function to create a wrapper script for a tool.
  make-tool-wrapper = tool-name: toolchain:
    pkgs.writeShellScriptBin "${toolchain.stdenv.cc.targetPrefix}${tool-name}" ''
      #!''${pkgs.bash}/bin/bash
      exec ${lib.getBin toolchain.stdenv.cc}/bin/${toolchain.stdenv.cc.targetPrefix}${tool-name} "$@"
    '';

  # Serial console connection script for BeagleBone Black
  bbb-serial = pkgs.writeShellScriptBin "bbb-serial" ''
    #!/usr/bin/env bash
    set -e

    BAUD=115200

    # Auto-detect serial device
    find_serial_device() {
      for dev in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
        if [ -e "$dev" ]; then
          echo "$dev"
          return 0
        fi
      done
      return 1
    }

    # Allow override via argument or environment
    DEVICE="''${1:-''${BBB_SERIAL_DEVICE:-}}"

    if [ -z "$DEVICE" ]; then
      DEVICE=$(find_serial_device) || {
        echo "Error: No serial device found."
        echo "Connect your USB-to-serial adapter and try again."
        echo "Or specify device: bbb-serial /dev/ttyUSB0"
        exit 1
      }
      echo "Auto-detected: $DEVICE"
    fi

    if [ ! -e "$DEVICE" ]; then
      echo "Error: Device $DEVICE does not exist"
      exit 1
    fi

    if [ ! -r "$DEVICE" ] || [ ! -w "$DEVICE" ]; then
      echo "Error: Cannot access $DEVICE"
      echo "You may need to add yourself to the dialout group:"
      echo "  sudo usermod -aG dialout \$USER"
      echo "Then log out and back in."
      exit 1
    fi

    echo "Connecting to $DEVICE at $BAUD baud..."
    echo "Exit with: Ctrl-a Ctrl-x"
    echo ""
    exec ${pkgs.picocom}/bin/picocom -b $BAUD "$DEVICE"
  '';

in
{
  # === MODULE OPTIONS ===
  options.customConfig.profiles.development.embedded-linux.devShell = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    description = "A unified dev shell for embedded Linux development.";
  };

  # === MODULE CONFIGURATION ===
  config = lib.mkIf cfg.enable {
    # Add user to dialout group for serial console access
    users.users.${config.customConfig.user.name}.extraGroups = [ "dialout" ];
    customConfig.profiles.development.embedded-linux.devShell =
      let
        pkgsQEMU = pkgs.pkgsCross.raspberryPi;
        pkgsBBB = pkgs.pkgsCross.armv7l-hf-multiplatform;

        # EXPANDED list of tools to wrap. U-Boot needs all of these.
        toolsToWrap = [ 
          "gcc" "g++" "ld" "ar" "nm" "objcopy" "objdump" 
          "ranlib" "readelf" "size" "strings" "strip" "as"
        ];

        qemuWrappers = map (tool-name: make-tool-wrapper tool-name pkgsQEMU) toolsToWrap;
        bbbWrappers = map (tool-name: make-tool-wrapper tool-name pkgsBBB) toolsToWrap;

      in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          # General build tools
          autoconf automake bc bison bzip2 cmake dtc flex gawk gcc gettext git gperf
          gnutls help2man libtool libuuid ncurses openssl patch python3 rsync swig texinfo unzip wget xz
          qemu_full ubootTools minicom picocom

          # SD card formatting utilities
          util-linux dosfstools e2fsprogs coreutils

          # The actual GDB/Binutils from the toolchains
          pkgsQEMU.gdb pkgsQEMU.binutils
          pkgsBBB.gdb pkgsBBB.binutils

          # Helper scripts
          bbb-serial
        ] ++ qemuWrappers ++ bbbWrappers;

        shellHook = ''
          export PS1='\[\033[1;33m\][embedded-linux]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
          echo "--------------------------------------------------------"
          echo "Entered Unified Embedded Linux Dev Shell."
          echo
          echo "Explicit compilers are now in your PATH."
          echo "To build U-Boot for BBB, use:"
          echo "  export CROSS_COMPILE=${pkgsBBB.stdenv.cc.targetPrefix}"
          echo
          echo "Serial console:"
          echo "  bbb-serial              # Auto-detect and connect"
          echo "  bbb-serial /dev/ttyUSB0 # Specify device"
          echo "--------------------------------------------------------"
        '';
      };
  };
}