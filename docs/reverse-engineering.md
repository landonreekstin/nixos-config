# Reverse engineering (REA + Ghidra)

`customConfig.profiles.development.reverse-engineering.enable` (on gaming-pc) installs
[REA — Reverse Engineer Anything](https://github.com/morluto/rea) for Claude Code, with
Ghidra and the other engines REA drives, plus a `~/reverse-engineering` workspace with
toolchains for writing recompilations.

- NixOS side: `modules/nixos/development/reverse-engineering.nix`
- Workspace (`.envrc`, parent `CLAUDE.md`): `modules/home-manager/development/reverse-engineering.nix`

## Using it

```bash
re new dxball          # creates ~/reverse-engineering/dxball/{target,notes,evidence,recomp,tests}
cp ~/Downloads/DXBALL.EXE ~/reverse-engineering/dxball/target/
re dxball              # Claude with REA's MCP tools + skill, toolchains on PATH
re dxball -c           # extra args go to claude (continue / resume)
re                     # numbered picker
rea doctor --json      # REA's own health check (same env as the MCP server)
```

Sessions run as **lando**, never `sudo` — REA can launch and debug the targets.
Original binaries live in `target/`, which every project gitignores.

## How it is put together

REA is an npm package (`rea-agents`): a CLI and a stdio MCP server. Its installer
(`rea setup`) writes `~/.claude.json` and copies a skill into `~/.claude/skills`; **we
don't use it.** Instead:

| Piece | What it is |
|---|---|
| `rea` | wrapper: exports `reaEnv` (every engine as an absolute store path — `GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `REA_*_COMMAND`), then `npx --yes rea-agents@<reaVersion>`. npx caches the pinned version in `~/.npm`. |
| REA plugin | a store-path Claude Code plugin: `.mcp.json` running `rea mcp`, and the `reverse-engineer-anything` skill copied from the **same npm tarball**. |
| `re` | launcher: `cd` into the project, put engines + recomp toolchains on PATH, `exec claude --plugin-dir <plugin>`. Only these sessions see REA's ~150 tools. |
| dev shell | `nix develop ~/nixos-config#reverse-engineering`, or direnv in `~/reverse-engineering`. Same tools and env as `re`, for working without Claude. |

Why not `buildNpmPackage`: REA's build is a turbo pipeline with prebuilt node-pty /
frida addons. The npx pin is REA's own recommended MCP registration and mirrors how
this repo runs `uvx mcp-nixos`.

Ghidra comes from `pkgs.unstable`: REA admits **only Ghidra 12.1.x**, and 26.05 ships
12.0.x. Drop the `unstable.` once stable reaches 12.1.

## Bumping REA

1. Set `reaVersion` in `modules/nixos/development/reverse-engineering.nix`.
2. Update `reaTarball`'s hash:
   `nix hash convert --hash-algo sha256 "$(nix-prefetch-url --unpack https://registry.npmjs.org/rea-agents/-/rea-agents-<ver>.tgz)"`
3. Rebuild, `rea --version`, `rea doctor --provider ghidra --json`.
4. Check REA's changelog for a new Ghidra/JDK requirement or new `REA_*` variables.

## Known gaps

- **WASM / logic signals**: REA wants WABT 1.0.42 and sigrok-cli 0.7.2; nixpkgs has
  1.0.41 and a 0.8 snapshot, so those two tools may refuse.
- **pwndbg** is not in nixpkgs; recorded-crash analysis uses plain GDB.
- **Android code decompilation** needs `REA_JADX_MCP_JAR` (a headless JADX bridge jar),
  not set up. APK resources via apktool work.
- **Hopper / IDA** are proprietary and not configured; Ghidra is the native engine.
- Byte-exact recompilation needs the original's compiler. mingw/gcc/clang are here;
  old MSVC/Borland/Watcom are not.

## mingw outside `nix develop`

The nixpkgs mingw gcc uses mcfgthread as its thread model and only finds its headers and
library through a mkShell setup hook, so a bare `i686-w64-mingw32-gcc` on PATH (as under
`re`) fails with `cannot find -lmcfgthread`. The module wraps both mingw compilers with
the `-isystem`/`-L` baked in, and exports `WINEPATH` with the mingw runtime DLL
directories (`libstdc++-6`, `libgcc_s_*`, `libmcfgthread-2`) so C++ or threaded
reconstructions run under wine without copying DLLs around. Project Makefiles need no
workarounds.
