# ~/nixos-config/modules/home-manager/development/reverse-engineering-rules.nix
#
# Not a module: the part of the reverse-engineering CLAUDE.md that is the same wherever a
# REA session runs. Imported by ./reverse-engineering.nix (lando's ~/reverse-engineering
# workspace) and ./vibe-projects.nix (insideabush's RE projects under ~/projects), which
# each put their own header above it.
{
  # How a session is allowed to run a target binary (one bullet, Markdown).
  runTargetRule,
  # Where a missing tool should be requested (one sentence, Markdown).
  missingToolRule,
}:

''
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
  ${runTargetRule}

  ## Tools on PATH

  `rea` (CLI, same environment as the MCP server), Ghidra GUI (`ghidra`), `rizin`,
  `cutter`, `gdb`, `objdump`, `imhex`, `wine`, `objdiff`, mingw/gcc/clang, `nasm`,
  and `python3` with pwntools, capstone, keystone, unicorn, lief, pyelftools and
  rzpipe. The mingw compilers link as-is (no `-L` for mcfgthread needed) and
  `WINEPATH` already holds the mingw runtime DLLs. `SDL2` + `pkg-config` for native
  front ends (`gcc main.c $(pkg-config --cflags --libs sdl2)`). ${missingToolRule}

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
''
