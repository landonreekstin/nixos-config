# ~/nixos-config/modules/home-manager/development/fpga-ice40.nix
{ config, pkgs, lib, customConfig, ... }:

let
  cfg = customConfig.profiles.development.fpga-ice40;
  hm = customConfig.homeManager;
  
  # The project directory will be created in the user's home
  projectDir = "${customConfig.user.home}/fpga-ice40";

  # This is a generic Makefile for the iCE40 toolchain
  makefileContent = ''
    # Makefile for iCE40 FPGA Development using Nix Open-Source Toolchain

    # --- Configuration ---
    # Target Verilog file (can be overridden from the command line)
    # Example: make TARGET=blinky
    TARGET ?= top

    # FPGA Board type (affects P&R and constraints)
    # Common boards: icestick, icebreaker, blackice-mx
    BOARD ?= icestick

    # --- Tool Configuration ---
    # Use tools from the Nix devShell
    YOSYS   = yosys
    NEXTPNR = next-pnr-ice40 # Corrected from nextpnr-ice40 for modern Nixpkgs
    ICEPACK = icepack
    ICEPROG = iceprog

    # --- Board-Specific Settings ---
    # Set device and package based on board
    ifeq ($(BOARD),icestick)
      DEVICE  = hx1k
      PACKAGE = tq144
      PCF_FILE = icestick.pcf # You must create this file!
    endif
    ifeq ($(BOARD),icebreaker)
      DEVICE  = up5k
      PACKAGE = sg48
      PCF_FILE = icebreaker.pcf # You must create this file!
    endif
    # Add other boards here...

    # --- File Names ---
    VERILOG_SRC = $(TARGET).v
    JSON_OUT    = $(TARGET).json
    ASC_OUT     = $(TARGET).asc
    BITSTREAM   = $(TARGET).bin

    # --- Makefile Targets ---

    .PHONY: all synth pnr pack flash clean help

    # Default target is to show help
    default: help

    # Build the bitstream
    all: $(BITSTREAM)

    # Synthesize: Verilog -> JSON Netlist
    $(JSON_OUT): $(VERILOG_SRC)
    	@echo "### Synthesizing with Yosys... ###"
    	$(YOSYS) -p "synth_ice40 -top $(TARGET) -json $(JSON_OUT)" $(VERILOG_SRC)

    # Place and Route: JSON Netlist -> ASCII Bitstream
    $(ASC_OUT): $(JSON_OUT) $(PCF_FILE)
    	@echo "### Placing and Routing with nextpnr... ###"
    	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $(JSON_OUT) --pcf $(PCF_FILE) --asc $(ASC_OUT)

    # Pack: ASCII Bitstream -> Binary Bitstream
    $(BITSTREAM): $(ASC_OUT)
    	@echo "### Packing bitstream with icepack... ###"
    	$(ICEPACK) $(ASC_OUT) $(BITSTREAM)

    # Flash: Upload bitstream to the board
    flash: all
    	@echo "### Flashing device with iceprog... ###"
    	$(ICEPROG) $(BITSTREAM)

    # Clean up generated files
    clean:
    	@echo "### Cleaning up build artifacts... ###"
    	rm -f $(JSON_OUT) $(ASC_OUT) $(BITSTREAM)

    # Help: Display this help message
    help:
    	@echo "Usage: make [VARIABLE=value] [target]"
    	@echo ""
    	@echo "Variables:"
    	@echo "  TARGET       The base name of the Verilog file (e.g., 'blinky' for blinky.v)."
    	@echo "               Default: '$(TARGET)'"
    	@echo "  BOARD        The target FPGA board (e.g., 'icestick', 'icebreaker')."
    	@echo "               Default: '$(BOARD)'"
    	@echo ""
    	@echo "Targets:"
    	@echo "  all          Builds the final bitstream ($(BITSTREAM))."
    	@echo "  flash        Builds the bitstream and flashes it to the board."
    	@echo "  synth        Run synthesis only (Verilog -> JSON)."
    	@echo "  pnr          Run place-and-route only (JSON -> ASC)."
    	@echo "  pack         Run bitstream packing only (ASC -> BIN)."
    	@echo "  clean        Remove all generated build files."
    	@echo "  help         Display this help message."
  '';

  readmeContent = ''
    # iCE40 FPGA Development Environment

    This directory is set up by NixOS/Home-Manager for FPGA development.
    When you `cd` into this directory, `direnv` will automatically load a shell
    with all the necessary tools (`yosys`, `nextpnr-ice40`, `icestorm`, etc.).

    ## Open-Source vs. Proprietary Tools

    The tutorials you are following might use proprietary software like Lattice iCEcube2.
    This environment provides the open-source equivalents:

    | Tutorial Step         | Open Source Tool | Makefile Command             | Description                                   |
    |-----------------------|------------------|------------------------------|-----------------------------------------------|
    | Synthesis             | `yosys`          | `make <name>.json`           | Converts Verilog code into a logic netlist.   |
    | Place & Route (P&R)   | `nextpnr`        | `make <name>.asc`            | Maps the logic onto the specific FPGA chip.   |
    | Create Bitstream      | `icepack`        | `make <name>.bin`            | Creates the final binary file for the FPGA.   |
    | Program Board         | `iceprog`        | `make flash TARGET=<name>`   | Uploads the binary file to the FPGA board.    |

    ## How to Use This Environment

    1.  **Create Your Verilog File**: Write your Verilog code in a file, for example, `blinky.v`.

    2.  **Create a PCF File**: You need a "Physical Constraints File" (`.pcf`) to map your Verilog input/output ports (like `LED`) to the physical pins on the FPGA. You will need to find a pinout diagram for your specific board. For an iCEstick, a `blinky.pcf` might contain:
        ```
        set_io CLK 12Mhz # Assuming you use the onboard clock
        set_io LED D1    # Maps the 'LED' wire in your Verilog to pin D1
        ```
       Name this file `icestick.pcf` to match the Makefile default.

    3.  **Build**: Run `make` commands from the terminal:
        *   `make TARGET=blinky`: Builds `blinky.bin`.
        *   `make flash TARGET=blinky`: Builds and then flashes the bitstream to the board.

    4.  **Change Board**: To target a different board (e.g., an iCEBreaker), edit the `Makefile` or run the command like this: `make BOARD=icebreaker TARGET=my_project`.
  '';

in
{
  config = lib.mkIf (cfg.enable && hm.enable) {

    # 1. Install direnv and enable it for your shell
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true; # Crucial for `use flake` integration
    };
    
    home.file."${projectDir}/.envrc" = {
      text = ''
        use flake ~/nixos-config#fpga-dev
      '';
    };

    # 3. Create the helpful Makefile and README in the project directory
    home.file."${projectDir}/Makefile".text = makefileContent;
    home.file."${projectDir}/README.md".text = readmeContent;
    
    # 4. Add recommended VS Code extensions for Verilog
    programs.vscode.extensions = with pkgs.vscode-extensions; [
      mshr-h.verilog-hdl
      eirikpre.systemverilog
    ];
  };
}