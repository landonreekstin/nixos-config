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
          qemu_full ubootTools

          # The actual GDB/Binutils from the toolchains
          pkgsQEMU.gdb pkgsQEMU.binutils
          pkgsBBB.gdb pkgsBBB.binutils
        ] ++ qemuWrappers ++ bbbWrappers;

        shellHook = ''
          export PS1='\[\033[1;33m\][embedded-linux]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
          echo "--------------------------------------------------------"
          echo "Entered Unified Embedded Linux Dev Shell."
          echo
          echo "Explicit compilers are now in your PATH."
          echo "To build U-Boot for BBB, use:"
          echo "  export CROSS_COMPILE=${pkgsBBB.stdenv.cc.targetPrefix}"
          echo "--------------------------------------------------------"
        '';
      };
  };
}