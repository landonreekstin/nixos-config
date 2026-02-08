# ~/nixos-config/modules/nixos/development/fpga-ice40.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.development.fpga-ice40;
in
{
  # This defines a new option that will hold the dev shell configuration.
  # We will later expose this in the flake's top-level `devShells`.
  options.customConfig.profiles.development.fpga-ice40.devShell = lib.mkOption {
    # This is the correct type for a derivation like a dev shell.
    type = with lib.types; package;
    # internal = true; # This line is not needed.
    description = "The development shell for iCE40 FPGA projects.";
  };

  config = lib.mkIf cfg.enable {
    # We assign the shell derivation to the option we just created.
    customConfig.profiles.development.fpga-ice40.devShell = pkgs.mkShell {
      name = "fpga-ice40-dev-shell";

      # Toolchain for iCE40 FPGAs
      packages = with pkgs; [
        # Synthesis
        yosys

        # Place-and-Route (with GUI for viewing)
        nextpnrWithGui

        # Bitstream tools and programmer
        icestorm

        # Verilog Simulator
        iverilog

        # Waveform Viewer
        gtkwave

        # For Makefile automation
        gnumake
      ];

      shellHook = ''
        export PS1='\[\033[1;36m\][fpga-dev]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
        echo "--- Nix FPGA iCE40 Development Environment ---"
        echo "Available commands: yosys, nextpnr-ice40, icepack, iceprog, iverilog, gtkwave, make"
        echo "Run 'make' to see build targets for a Verilog file."
        echo "------------------------------------------------"
      '';
    };
  };
}