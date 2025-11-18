# ~/nixos-config/modules/nixos/development/embedded-linux.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.embedded-linux;

  # Helper function to create a wrapper script for a tool.
  # It takes a tool name (like "gcc") and a toolchain package set.
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

        # List of common tools we want to wrap for each toolchain
        toolsToWrap = [ "gcc" "g++" "ld" "strip" "objcopy" ];

        # Create the wrapper packages for all tools for both toolchains
        qemuWrappers = map (tool-name: make-tool-wrapper tool-name pkgsQEMU) toolsToWrap;
        bbbWrappers = map (tool-name: make-tool-wrapper tool-name pkgsBBB) toolsToWrap;

      in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          # General build tools
          autoconf automake bison bzip2 cmake flex gawk gcc gettext git gperf
          help2man libtool ncurses patch python3 rsync texinfo unzip wget xz
          qemu_full ubootTools

          # The actual GDB/Binutils from the toolchains (these don't conflict)
          pkgsQEMU.gdb pkgsQEMU.binutils
          pkgsBBB.gdb pkgsBBB.binutils
        ] ++ qemuWrappers ++ bbbWrappers; # Add our new wrappers to the inputs

        shellHook = ''
          echo "--------------------------------------------------------"
          echo "Entered Unified Embedded Linux Dev Shell."
          echo
          echo "Explicit compilers are now in your PATH."
          echo "Use them directly, for example:"
          echo "  ${pkgsBBB.stdenv.cc.targetPrefix}gcc -o hello hello.c"
          echo "  ${pkgsQEMU.stdenv.cc.targetPrefix}gcc -o hello hello.c"
          echo
          echo "Tab completion for '${pkgsBBB.stdenv.cc.targetPrefix}' will show all tools."
          echo "--------------------------------------------------------"
        '';
      };
  };
}