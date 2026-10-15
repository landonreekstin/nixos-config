# ~/nixos-config/modules/home-manager/development/reverse-engineering.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.reverse-engineering;
  dir = "${config.home.homeDirectory}/reverse-engineering";

  envrcContent = ''
    # Managed by your NixOS config. Activates the reverse-engineering dev shell.
    use flake ~/nixos-config#reverse-engineering
    export DEV_ENV_NAME="reverse-engineering"
  '';

  # Rules every project session inherits: Claude Code collects CLAUDE.md from the
  # working directory upwards, so this reaches ~/reverse-engineering/<project> too.
  workspaceClaudeMd = ''
    # Reverse-engineering workspace

    *Managed by nixos-config (modules/home-manager/development/reverse-engineering.nix).
    Edits here are overwritten on rebuild — change the module instead.*

    Each subdirectory is one project, created with `re new <name>` and opened with
    `re <name>`. `re` is what loads REA: it starts Claude with the REA plugin (MCP server
    + `reverse-engineer-anything` skill) and the recompilation toolchains on PATH. A plain
    `claude` started here has neither — if REA's tools are missing, say so and ask the
    user to relaunch through `re` rather than running `rea setup`.

    ## Project layout

    | Path | Holds |
    |---|---|
    | `target/` | the original binaries/apps under study. **Gitignored — never commit them.** |
    | `notes/` | findings, open questions, and the unknowns REA reports |
    | `evidence/` | REA Evidence records / exports worth keeping |
    | `recomp/` | the reconstruction: `src/*.c`, built by `recomp/Makefile` |
    | `tests/` | the harness that compares original and reconstruction |
    | `CLAUDE.md` | what the target is and how far the reconstruction has got — keep it current |

    ## How to work

    - Record the target's SHA-256 in the project CLAUDE.md before analysing it.
    - Start from REA's evidence (decompilation, assembly, xrefs), not guesses. Ghidra
      pseudocode is a lead, not source: check it against the instructions.
    - Write unknowns down in `notes/` instead of papering over them.
    - A reconstruction counts as correct only when it is **checked against the
      original**:
      - behaviour: run both on the same inputs (Windows originals under `wine`; a lone
        function under `unicorn` in Python) and diff the outputs;
      - code: build with the matching compiler (`i686-w64-mingw32-gcc`,
        `x86_64-w64-mingw32-gcc`, `gcc`, `clang`) and compare with `objdiff` or
        `objdump -d`. A byte match needs the original's compiler and flags; say how
        close you got rather than claiming a match.
    - Analysed binaries may be hostile. Don't run a target outside a test you set up
      on purpose, and never with sudo.

    ## Tools on PATH

    `rea` (CLI, same environment as the MCP server), Ghidra GUI (`ghidra`), `rizin`,
    `cutter`, `gdb`, `objdump`, `imhex`, `wine`, `objdiff`, mingw/gcc/clang, `nasm`,
    and `python3` with pwntools, capstone, keystone, unicorn, lief, pyelftools and
    rzpipe. The mingw compilers link as-is (no `-L` for mcfgthread needed) and
    `WINEPATH` already holds the mingw runtime DLLs. `SDL2` + `pkg-config` for native
    front ends (`gcc main.c $(pkg-config --cflags --libs sdl2)`). Missing a tool? It
    belongs in `~/nixos-config/modules/nixos/development/reverse-engineering.nix`.

    ## Console / embedded ROMs (headerless, odd CPUs)

    - `mame` is the reference implementation: run the original (`mame -listfull <set>`
      to identify it), its debugger, `-debugscript`, tracing and Lua for harnesses.
      `$MAME_SRC` is the source of that exact MAME version (drivers and chip emulation:
      `src/mame/`, `src/devices/`).
    - `unidasm <file> -arch <cpu>` disassembles any CPU MAME emulates (`unidasm -h`
      lists them). Little-endian 16-bit ISAs need `-xchbytes`.
    - `naken_asm` assembles many small ISAs (`.unsp`, `.6502`, `.msp430`, ...), for
      checking that a reading of the code round-trips to the same bytes.
    - Ghidra ships extra processors here: **Sunplus µ'nSP** (`unsp:LE:16:default`, SPG2xx
      plug-and-play games; community module, incomplete). REA's raw-binary loader only
      knows its own CPU list, so load these with Ghidra directly:
      `ghidra-analyzeHeadless <projdir> <name> -import rom.bin -loader BinaryLoader
      -processor unsp:LE:16:default -postScript <script>` (the project dir must not sit
      under a dot-directory). µ'nSP space is word-addressed: use `toAddr("0x5dcd")`,
      not a byte offset. The `ghidra` GUI has the same processors.
  '';

  # Real files, not home.file symlinks into the store: direnv needs to update the
  # .envrc timestamp, and rewriting an unchanged .envrc would force a re-allow.
  writeIfChanged = path: content: ''
    content=${lib.escapeShellArg content}
    if [ ! -f "${path}" ] || [ "$(cat "${path}")" != "$content" ]; then
      [ -L "${path}" ] && rm "${path}"
      printf '%s' "$content" > "${path}"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.activation.createReverseEngineeringWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dir}"

      ${writeIfChanged "${dir}/.envrc" envrcContent}
      ${writeIfChanged "${dir}/CLAUDE.md" workspaceClaudeMd}
    '';
  };
}
