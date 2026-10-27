# ~/nixos-config/modules/nixos/development/reverse-engineering.nix
{ config, pkgs, lib, ... }:

# REA ("Reverse Engineer Anything", github.com/morluto/rea) wired up for Claude Code,
# plus a ~/reverse-engineering workspace with recompilation toolchains.
# See docs/reverse-engineering.md.
#
# REA is an npm package (`rea-agents`): a CLI and a stdio MCP server that drive
# analysis engines the caller supplies. Its own installer (`rea setup`) mutates
# ~/.claude.json and copies a skill into ~/.claude/skills; none of that is used here.
# Instead every engine is pinned to a store path in `reaEnv`, and the MCP server +
# skill are packaged as a Claude Code plugin that only the `re` launcher loads.

let
  cfg = config.customConfig.profiles.development.reverse-engineering;
  userHome = config.customConfig.user.home;
  workspace = "${userHome}/reverse-engineering";

  # Bump both together: the skill is taken from the same published tarball the MCP
  # server runs, so the instructions never describe tools the server doesn't have.
  reaVersion = "6.5.0";
  reaTarball = pkgs.fetchzip {
    url = "https://registry.npmjs.org/rea-agents/-/rea-agents-${reaVersion}.tgz";
    hash = "sha256-UqNA2ChHfWDHIJoCP3qvIUpOEdMJa3Lzu3kZpy5BVIM=";
  };

  # REA admits only Ghidra 12.1.x; 26.05 ships 12.0.x.
  ghidraBase = pkgs.unstable.ghidra;

  # Sunplus µ'nSP (SPG2xx plug-and-play TV games). Ghidra ships no processor for it.
  # Community SLEIGH module, incomplete but usable; the .sla is compiled here because
  # Ghidra would otherwise try to compile it on first use, inside the read-only store.
  ghidraUnsp = ghidraBase.buildGhidraExtension {
    pname = "ghidra-unsp";
    version = "0-unstable-2023-07-08";
    src = pkgs.fetchFromGitHub {
      owner = "SamuelWAnderson45";
      repo = "ghidra-unSP";
      rev = "058b4cc48bf3f76bff1d0d84d8d73c26b67cc0d5";
      hash = "sha256-LC2L5jtmIu3QJb3dtdZfle64lw6cGQr3R0eBfu6smOo=";
    };
    postInstall = ''
      ext=$out/lib/ghidra/Ghidra/Extensions/ghidra-unsp
      rm -f $ext/.dbDirLock
      ${ghidraBase}/lib/ghidra/support/sleigh -a $ext/data/languages
    '';
  };
  # withExtensions does not build a new install dir: the launchers find extensions
  # through NIX_GHIDRAHOME, which REA's headless runs get from reaEnv below.
  ghidra = ghidraBase.withExtensions (_: [ ghidraUnsp ]);
  jdk = pkgs.openjdk21; # what nixpkgs builds Ghidra with; REA wants a full JDK (javac)

  # MAME's tools output (unidasm, chdman, romcmp, ...) links sdl2-compat, which dlopens
  # SDL3 and does not find it. unidasm -arch unsp12 -xchbytes disassembles SPG2xx ROMs.
  mameTools = pkgs.symlinkJoin {
    name = "mame-tools-${pkgs.mame.version}";
    paths = [ pkgs.mame.tools ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for tool in $out/bin/*; do
        wrapProgram "$tool" --prefix LD_LIBRARY_PATH : ${lib.getLib pkgs.sdl3}/lib
      done
    '';
  };

  # Assembler for many small ISAs incl. µ'nSP (`.unsp`), for round-tripping asm.
  nakenAsm = pkgs.stdenv.mkDerivation {
    pname = "naken_asm";
    version = "0-unstable-2026-05-30";
    src = pkgs.fetchFromGitHub {
      owner = "mikeakohn";
      repo = "naken_asm";
      rev = "247c23706909f09bac77c587780b8a826bbda27c";
      hash = "sha256-yU5wXuvjzFFtvct7/PIFlKR8nHJdT7fxI42AKox9sfc=";
    };
  };

  python = pkgs.python3.withPackages (ps: with ps; [
    pwntools       # REA's ELF layout / recorded-crash tools (REA_PWNTOOLS_PYTHON)
    capstone       # disassembly
    keystone-engine # assembly
    unicorn        # CPU emulation — run a lone function from the original
    lief           # PE/ELF/Mach-O parsing and patching
    pyelftools
    rzpipe
  ]);

  # Engines REA drives. On the MCP server's PATH and in the dev shell.
  analysisTools = with pkgs; [
    nodejs_24      # REA itself (npx)
    procps         # REA refuses to launch Ghidra/JADX/JS analysis without a procps `ps`
    util-linux     # prlimit
    coreutils
    file
    binutils
    gdb
    rizin
    wireshark-cli
    binwalk
    unstable.unblob  # stable fails a tar test, so Hydra never cached it
    apktool
    jadx
    wabt
    sigrok-cli
    mitmproxy
    android-tools
    mame           # reference emulator: debugger, tracing, Lua; covers plug-and-play/arcade targets
    mameTools
    ppsspp         # reference PSP emulator: built-in + web debugger; ppsspp-headless for scripted runs
    nakenAsm
    jdk
    python
  ];

  # Every value is absolute so the server behaves the same whatever PATH Claude has.
  reaEnv = {
    GHIDRA_INSTALL_DIR = "${ghidraBase}/lib/ghidra";
    NIX_GHIDRAHOME = "${ghidra}/lib/ghidra/Ghidra"; # base modules + ghidra-unsp
    JAVA_HOME = "${jdk}/lib/openjdk";
    GHIDRA_HEADLESS_MAXMEM = "8G";
    REA_GHIDRA_STARTUP_TIMEOUT_MS = "900000";
    REA_GDB_COMMAND = "${pkgs.gdb}/bin/gdb";
    REA_RIZIN_COMMAND = "${pkgs.rizin}/bin/rizin";
    REA_OBJDUMP_COMMAND = "${pkgs.binutils}/bin/objdump";
    REA_TSHARK_COMMAND = "${pkgs.wireshark-cli}/bin/tshark";
    REA_CAPINFOS_COMMAND = "${pkgs.wireshark-cli}/bin/capinfos";
    REA_TSHARK_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
    REA_BINWALK_COMMAND = "${pkgs.binwalk}/bin/binwalk";
    REA_UNBLOB_COMMAND = "${pkgs.unstable.unblob}/bin/unblob";
    REA_APKTOOL_COMMAND = "${pkgs.apktool}/bin/apktool";
    REA_WABT_BIN_DIRECTORY = "${pkgs.wabt}/bin";
    REA_SIGROK_COMMAND = "${pkgs.sigrok-cli}/bin/sigrok-cli";
    REA_MITMDUMP_COMMAND = "${pkgs.mitmproxy}/bin/mitmdump";
    REA_ADB_PATH = "${pkgs.android-tools}/bin/adb";
    REA_PWNTOOLS_PYTHON = "${python}/bin/python3";
  };
  reaExports = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") reaEnv);

  # The one entry point for both the CLI and the MCP server (`rea mcp`). npx caches
  # the pinned version in ~/.npm after the first run.
  rea = pkgs.writeShellApplication {
    name = "rea";
    runtimeInputs = analysisTools;
    text = ''
      ${reaExports}
      export NPM_CONFIG_UPDATE_NOTIFIER=false
      exec npx --yes rea-agents@${reaVersion} "$@"
    '';
  };

  # MCP server + skill as a Claude Code plugin, loaded per session with --plugin-dir,
  # so only RE sessions see REA's tools.
  reaPlugin = pkgs.runCommand "rea-claude-plugin-${reaVersion}" { } ''
    mkdir -p $out/.claude-plugin $out/skills
    cat > $out/.claude-plugin/plugin.json <<'EOF'
    ${builtins.toJSON {
      name = "rea";
      version = reaVersion;
      description = "REA reverse-engineering MCP server and skill (managed by nixos-config)";
    }}
    EOF
    cat > $out/.mcp.json <<'EOF'
    ${builtins.toJSON {
      mcpServers.rea = { command = "${rea}/bin/rea"; args = [ "mcp" ]; };
    }}
    EOF
    cp -r ${reaTarball}/skills/reverse-engineer-anything $out/skills/
  '';

  # The nixpkgs mingw gcc uses mcfgthread as its thread model: it links -lmcfgthread
  # into every program and its C++ headers include <mcfgthread/gthr.h>, but it only
  # learns where those live from a mkShell setup hook. Outside `nix develop` (so under
  # `re`) every link fails. Bake the paths into the compiler drivers instead.
  mingwGcc = cross:
    let mcf = cross.windows.mcfgthreads; in
    pkgs.symlinkJoin {
      name = "${cross.stdenv.hostPlatform.config}-gcc-mcfgthread";
      paths = [ cross.buildPackages.gcc ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for tool in $out/bin/*-gcc $out/bin/*-g++ $out/bin/*-c++ $out/bin/*-cc; do
          [ -e "$tool" ] || continue
          wrapProgram "$tool" --append-flags "-isystem ${mcf.dev}/include -L${mcf}/lib"
        done
      '';
    };
  mingw32Gcc = mingwGcc pkgs.pkgsCross.mingw32;
  mingw64Gcc = mingwGcc pkgs.pkgsCross.mingwW64;

  # Where wine finds the mingw runtime DLLs (libstdc++-6, libgcc_s_*, libmcfgthread-2)
  # that a C++ or threaded reconstruction imports. Wine skips a wrong-arch DLL and
  # keeps searching, so the 32- and 64-bit directories can share one path.
  mingwDllDirs = cross: [
    "${cross.buildPackages.gcc.cc.lib}/${cross.stdenv.hostPlatform.config}/lib"
    "${cross.windows.mcfgthreads}/bin"
  ];
  recompEnv = {
    WINEPATH = lib.concatStringsSep ";"
      (mingwDllDirs pkgs.pkgsCross.mingw32 ++ mingwDllDirs pkgs.pkgsCross.mingwW64);
    # Source of the MAME packaged above, for reading drivers and chip emulation as a
    # reference (e.g. src/devices/cpu/unsp, src/devices/machine/spg2xx*).
    MAME_SRC = "${pkgs.mame.src}";
  };
  recompExports = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") recompEnv);

  # Toolchains for writing and checking recompilations.
  recompTools = with pkgs; [
    gcc
    clang
    lld
    mingw32Gcc   # i686-w64-mingw32-gcc: 32-bit Windows PEs
    mingw64Gcc   # x86_64-w64-mingw32-gcc
    nasm
    cmake
    ninja
    gnumake
    wineWow64Packages.stable  # run original Windows binaries (32- and 64-bit) for differential tests; the cached build
    unstable.objdiff        # function-level byte diff, recompile vs original
    SDL2          # front ends for reconstructed games (sdl2-compat, on SDL3)
    pkg-config
    upx
    patchelf
    ltrace
    strace
    hexyl
    git
  ];

  # --- Project scaffold ---------------------------------------------------------------
  projectGitignore = pkgs.writeText "re-gitignore" ''
    # Original binaries are other people's code: analyse them, never commit them.
    target/
    # Build output
    build/
    recomp/build/
    *.o
    *.obj
    .direnv/
  '';

  projectClaudeMd = pkgs.writeText "re-project-CLAUDE.md" ''
    *Created by `re new`. The rules for every RE project are in `../CLAUDE.md`.*

    ## Target

    *(What binary/app is in `target/`, where it came from, its SHA-256, and the question
    being answered.)*

    ## Status

    *(What has been recovered, what is reconstructed in `recomp/`, and how closely it
    matches — test cases passing, functions byte-identical.)*
  '';

  projectMakefile = pkgs.writeText "re-Makefile" ''
    # Reconstruction build. Pick the compiler that matches the original:
    #   CC=i686-w64-mingw32-gcc   (32-bit Windows PE)
    #   CC=x86_64-w64-mingw32-gcc (64-bit Windows PE)
    #   CC=gcc                    (native Linux ELF)
    CC ?= gcc
    CFLAGS ?= -O2 -g
    SRC := $(wildcard src/*.c)
    OUT ?= build/recomp

    $(OUT): $(SRC)
    	mkdir -p build
    	$(CC) $(CFLAGS) -o $@ $(SRC)

    clean:
    	rm -rf build

    .PHONY: clean
  '';

  # Every entry point into a REA session goes through this: `re` below, and the
  # reverse-engineering mode of `vibe` (modules/nixos/programs/vibe-projects.nix). Its own
  # store script rather than a function inside `re` because `vibe` runs it under `sudo`,
  # which resets the environment — the exports have to happen after sudo, not before.
  launcher = pkgs.writeShellScript "re-claude" ''
    # Same env as the dev shell, without the nix-develop round trip.
    export PATH=${lib.makeBinPath (analysisTools ++ recompTools ++ [ rea ])}:"$PATH"
    ${reaExports}
    ${recompExports}
    # mkShell builds this from its inputs; here only the front-end libraries need it.
    export PKG_CONFIG_PATH=${lib.makeSearchPath "lib/pkgconfig" [ (lib.getDev pkgs.SDL2) ]}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
    export DEV_ENV_NAME="reverse-engineering"
    exec claude --plugin-dir ${reaPlugin} "$@"
  '';

  # Lays out a project directory. Shared with `vibe` for the same reason as `launcher`;
  # each caller writes its own CLAUDE.md and runs its own `git init`.
  scaffold = pkgs.writeShellScript "re-scaffold" ''
    set -eu
    dir="$1"
    mkdir -p "$dir"/target "$dir"/notes "$dir"/evidence "$dir"/recomp/src "$dir"/tests
    install -m 644 ${projectGitignore} "$dir/.gitignore"
    install -m 644 ${projectMakefile} "$dir/recomp/Makefile"
  '';

  re = pkgs.writeShellApplication {
    name = "re";
    runtimeInputs = with pkgs; [ coreutils git findutils ];
    text = ''
      ws=${lib.escapeShellArg workspace}
      mkdir -p "$ws"

      usage() {
        cat <<'EOF'
      re                 pick a project (or start one) and open Claude in it
      re new <name>      create ~/reverse-engineering/<name>
      re <name> [args]   open Claude in a project; extra args go to claude (-c, -r ...)
      re ls              list projects
      EOF
      }

      create() {
        local name="$1" dir="$ws/$1"
        if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
          echo "re: project names are letters, digits, '.', '_' and '-' only" >&2; exit 1
        fi
        if [ -e "$dir" ]; then echo "re: $dir already exists" >&2; exit 1; fi
        ${scaffold} "$dir"
        install -m 644 ${projectClaudeMd} "$dir/CLAUDE.md"
        git -C "$dir" init -q -b main
        echo "Created $dir — put the binary you want to study in $dir/target/"
      }

      open_project() {
        local dir="$ws/$1"; shift
        if [ ! -d "$dir" ]; then echo "re: no project '$1' in $ws (re new <name>)" >&2; exit 1; fi
        cd "$dir"
        exec ${launcher} "$@"
      }

      projects() { find "$ws" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort; }

      case "''${1:-}" in
        -h|--help|help) usage ;;
        ls) projects ;;
        new)
          [ -n "''${2:-}" ] || { usage; exit 1; }
          create "$2"
          ;;
        "")
          mapfile -t list < <(projects)
          echo "Reverse-engineering projects in $ws:"
          for i in "''${!list[@]}"; do printf '  %d) %s\n' "$((i + 1))" "''${list[$i]}"; done
          echo "  n) new project"
          read -rp "> " pick
          if [ "$pick" = n ]; then
            read -rp "Project name: " name
            create "$name"
            open_project "$name"
          elif [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "''${#list[@]}" ]; then
            open_project "''${list[$((pick - 1))]}"
          else
            echo "re: nothing picked" >&2; exit 1
          fi
          ;;
        *) open_project "$@" ;;
      esac
    '';
  };
in
{
  options.customConfig.profiles.development.reverse-engineering.devShell = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Dev shell for the ~/reverse-engineering workspace.";
  };

  options.customConfig.profiles.development.reverse-engineering.enable = with lib; mkOption {
    type = types.bool;
    default = false;
    description = ''
      Install REA (Reverse Engineer Anything) with Ghidra and the analysis engines it
      drives, the `re` launcher that opens Claude Code with REA's MCP server and skill,
      and the `reverse-engineering` dev shell used by ~/reverse-engineering.
    '';
  };

  options.customConfig.profiles.development.reverse-engineering.workspace.enable = with lib; mkOption {
    type = types.bool;
    default = true;
    description = ''
      Install the `re` command and create the ~/reverse-engineering workspace. Turn this
      off where REA is only reached through `vibe` (blaney-pc): `re` runs Claude without
      sudo, and that user's Claude login exists only for root.
    '';
  };

  # Read-only hooks for `vibe` (modules/nixos/programs/vibe-projects.nix), so its
  # reverse-engineering projects open in exactly the environment `re` sets up.
  options.customConfig.profiles.development.reverse-engineering.launcher = lib.mkOption {
    type = lib.types.package;
    internal = true;
    readOnly = true;
    default = launcher;
    description = "`claude` wrapper with REA's plugin, engines and recomp toolchains.";
  };

  options.customConfig.profiles.development.reverse-engineering.scaffold = lib.mkOption {
    type = lib.types.package;
    internal = true;
    readOnly = true;
    default = scaffold;
    description = "Script that lays out a reverse-engineering project directory.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      rea
      ghidra      # GUI, for looking at what REA found by hand
      pkgs.cutter
      pkgs.imhex
      pkgs.ppsspp # PSP targets, by hand
    ] ++ lib.optional cfg.workspace.enable re;

    customConfig.profiles.development.reverse-engineering.devShell = pkgs.mkShell {
      name = "reverse-engineering";
      packages = analysisTools ++ recompTools ++ [ rea ];
      shellHook = ''
        ${reaExports}
        ${recompExports}
        export DEV_ENV_NAME="reverse-engineering"
      '';
    };
  };
}
