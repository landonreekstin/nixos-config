# ~/nixos-config/modules/profiles/development/kernel.nix
{ lib, config, pkgs, ... }:

let
  # Shorthand for the profile's enable flag.
  cfg = config.customConfig.profiles.development.kernel;
in
{
  # === MODULE OPTIONS ===
  # This section defines the configuration options that this module is responsible for.
  # We define a `devShell` option here to hold the shell's configuration.
  options.customConfig.profiles.development.kernel.devShell = lib.mkOption {
    type = lib.types.attrs; # The type will be an attribute set, compatible with pkgs.mkShell
    internal = true; # This option is for internal use by our flake, not for users to set.
    description = "The attribute set for the kernel development shell.";
  };

  # === MODULE CONFIGURATION ===
  # This section provides the actual implementation for the options above.
  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.kernel.devShell = {
      buildInputs = with pkgs; [
        # Core Build Tools
        git
        gnumake
        gcc
        ncurses
        bc
        binutils
        flex
        bison
        elfutils
        openssl
        util-linux
        pkg-config
        
        # QEMU for running the kernel
        qemu_kvm
        debootstrap # Needed for building the guest image

        # Debugging Tools
        gdb
        
        # Clang and LLVM Toolchain
        clang
        clang-tools
        lld
        llvm
        
        # Static Analysis & Code Tools
        cppcheck
        cscope
        curl
        fakeroot
        flawfinder
        indent # gnu-indent
        sparse
        
        # System & Performance Analysis Tools
        gnuplot
        hwloc
        numad
        man-db
        numactl
        psmisc
        python3
        perl
        pahole
        rt-tests
        smem
        stress
        sysfsutils
        trace-cmd
        tree
        tuna
        virt-what
        zlib
        
        # General Utilities
        tldr
      ];

      # This hook will run when you enter the shell.
      # We will add more to this later.
      shellHook = ''
        echo "Entered Linux Kernel Development Shell."
        echo "NOTE: Helper scripts (run-qemu, etc.) will be added in the next step."
      '';
    };
  };
}