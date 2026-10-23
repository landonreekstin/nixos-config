<!-- ~/nixos-config/docs/hosts/blaney-vibe-projects.md -->
> **Read this when**: working on the `vibe` command, adding a language toolchain for one of
> insideabush's own app projects, or packaging one of his finished apps. The general
> blaney-pc rules in [blaney-pc.md](blaney-pc.md) still apply to anything that touches this
> repo.

# Blaney's vibe-coded app projects

insideabush builds his own small desktop apps by vibe coding them with Claude. `vibe` is
his front door to that: it creates a project or puts him back into one, and the session it
opens is governed by *its own* rules, not this repo's.

The point of the split: **his app source is not part of this repo.** Each project is a
local-only git repo in `~/projects/<slug>` that he commits to `main` freely. Only two
things ever come back here as a `blaney/` PR — a new language toolchain, and packaging a
finished app.

**Nothing in `~/projects` is backed up or pushed anywhere.** If that disk dies, every
project is gone, on a machine nobody can reach physically. That is an accepted trade for
not handing a non-technical user a remote and credentials; it is also why the rules tell
Claude to commit early and often.

## The layout

```
/home/insideabush/projects/
  CLAUDE.md              <- THE RULES. home-manager store symlink, immutable
  README.md              <- plain-English "type vibe", also home-manager
  snake-game/
    .vibe-project        title= slug= shell=   <- what makes this a vibe project
    .envrc               use flake ~/nixos-config#vibe-python
    CLAUDE.md            what THIS app is; points up at the rules
    .git/                local only, no remote
```

**`~/projects/CLAUDE.md` is the load-bearing file.** Claude Code collects `CLAUDE.md` from
the working directory *upwards*, so one file above the projects applies to every project on
every session — including the ones started by `claude -c` and `claude -r`, which carry **no
prompt at all**. Rules kept only in the launch prompt would silently vanish on every
resumed session, i.e. on most of them. Rules copied into each project at creation time
would instead go stale the first time one changed. Hence: one immutable file, one directory
up. It is a store symlink, so a session cannot rewrite it and every rebuild re-asserts it.

Each project's own `CLAUDE.md` holds only what that app *is*, plus an explicit pointer up to
`../CLAUDE.md` as a belt-and-braces in case the upward discovery ever does not fire.

`.vibe-project` is the marker. `vibe` finds his apps by globbing
`~/projects/*/.vibe-project`, reads `title=` for the menu entry and `shell=` for the
language shown beside it. It is read with `sed`, never `source`d — `title=` is arbitrary
text he typed. **Don't rename a project folder by hand**: `.envrc`, and Claude's saved
chats, are keyed to the path.

## The loop

1. He runs `vibe`. With no projects yet it goes straight to the new-app flow; otherwise it
   offers "work on an app you already started" / "start a brand new app".
2. **New app:** it asks for a plain-English name, slugifies it to `[a-z0-9-]` (so no title
   can produce `.`, `..` or a path separator), makes the directory, runs `git init -b main`,
   writes `.vibe-project` / `.gitignore` / `CLAUDE.md`, commits, and launches Claude in it.
3. **Existing app:** pick the app, then pick up the last chat (`claude -c`), start a fresh
   chat, or browse older chats (`claude -r`). The first and last are offered **only when a
   saved chat actually exists** — `claude -c` errors out in a directory with no history,
   which is not something he could act on.
4. The session asks him what the app should do and look like, **picks the language itself**,
   writes `.envrc`, records `shell=`, allows direnv, and builds it.

`vibe` deliberately never asks a technical question — per
[blaney-pc.md](blaney-pc.md#decision-authority) he makes no technical decisions, so the
language choice belongs to the session, after it knows what the app is for.

## Where the pieces live

| What | Where |
|---|---|
| `vibe`, the per-project CLAUDE.md template, the launch prompt, `vibe-prepare` | `modules/nixos/programs/vibe-projects.nix` (`customConfig.programs.vibeProjects`) |
| **The rules** (`~/projects/CLAUDE.md`) + `~/projects/README.md` | `modules/home-manager/development/vibe-projects.nix` |
| The language toolchains | `modules/nixos/development/vibe-python.nix`, `vibe-web.nix` |
| Enabled for the host | `hosts/blaney-pc/{apps,profiles}.nix`, mirrored in `hosts/vm-blaney/` |
| Reverse-engineering mode (REA launcher, scaffold, shared RE rules) | `modules/nixos/development/reverse-engineering.nix`, `modules/home-manager/development/reverse-engineering-rules.nix` — see [below](#reverse-engineering-projects) |

`vibe-prepare` is a root-only store script, never advertised in `blaney-help`, that `vibe`
calls once per launch via `sudo`. It does two things that need root and are best done in a
single call so he types his password at most once: pre-accepts the per-directory
workspace-trust flag in `/root/.claude.json` (the same key
`modules/nixos/programs/claude-code.nix` seeds for its remote-control directories, but for
a directory that only exists at runtime), and counts the saved chats under
`/root/.claude/projects/<cwd-with-dashes>/` — which `vibe` cannot do itself, since it runs
as insideabush and that tree is `0700 root`.

### `vibe` cannot be run from inside a Claude session

It ends in `exec sudo claude`, and Claude sessions do not nest. So a `blaney-todo` session
cannot drive `vibe` to test it, and neither can any other session — including one of
lando's. Anything that wants Blaney in a vibe project has to **tell him to type `vibe`**,
which is the one place handing him a command is correct: it is the entry point to a
different session, not a chore being offloaded. `docs/runbooks/blaney/06-build-your-first-app.md`
is written that way.

## Reverse-engineering projects

Where `customConfig.profiles.development.reverse-engineering.enable` is on (blaney-pc),
`vibe` offers a third choice: **take apart a program or game**. It is the `re` setup from
[reverse-engineering.md](../reverse-engineering.md) (REA's MCP server and skill, Ghidra,
MAME, wine, the mingw compilers) applied to a vibe project, with every vibe rule unchanged.
On a host without the profile, the menu has no third entry and `vibe`'s closure holds no
RE store paths.

- **Same directory, different marker.** An RE project is `~/projects/<slug>` with
  `kind=re` (and `shell=reverse-engineering`) in `.vibe-project`. Keeping it under
  `~/projects` is the point: `~/projects/CLAUDE.md` is the file parent discovery already
  loads on every session, `-c`/`-r` included. The RE rules are a section at the end of that
  file, emitted only when the profile is on and scoped to `kind=re` projects. The second
  half of that section is `reverse-engineering-rules.nix`, the same text lando's
  `~/reverse-engineering/CLAUDE.md` uses, so the two cannot drift. The pick list labels
  these projects `(taking apart)`.
- **Every launch goes through the launcher, resumed chats included.** The
  `reverse-engineering.launcher` option is the `re-claude` store script that `re` itself
  now execs. It puts the toolchain on PATH, exports `reaEnv`, and runs
  `claude --plugin-dir <rea plugin>`. `vibe` calls `sudo <launcher> [-c|-r|prompt]`. The
  wrapper has to run *after* sudo because sudo's `env_reset` would drop `GHIDRA_INSTALL_DIR`
  and the rest. A plain `sudo claude -c` in an RE project would resume the chat with no REA
  tools.
- **The layout comes from `re`'s own scaffold.** `reverse-engineering.scaffold`
  (`re-scaffold <dir>`) creates `target/ notes/ evidence/ recomp/ tests/`, the
  target-ignoring `.gitignore` and `recomp/Makefile`. `vibe` then appends its own
  `.gitignore` lines and writes its own CLAUDE.md template.
- **Targets run as him, not root.** On gaming-pc RE sessions run as lando on purpose,
  because REA executes and debugs the binaries under study. Here the session must be root,
  since his Claude login only exists for root. So the rules require every target, `wine`,
  `mame` or reconstruction test to run as `runuser -u insideabush -- <cmd>`. runuser keeps
  PATH and `WINEPATH` (checked) and gives the command his HOME, so a wine prefix lands in
  his home. **Residual risk:** REA's own dynamic tools (gdb and so on) still run as root.
- **`workspace.enable = false` on blaney-pc.** That hides `re` and does not create
  `~/reverse-engineering`. `re` runs Claude without sudo, where he has no login, and the
  workspace rules talk about lando's setup. Ghidra, Cutter, ImHex and `rea` stay installed.

Everything the profile pulls in is in cache.nixos.org (checked when this was added: mame,
mame.tools, unstable ghidra/unblob/objdiff, both mingw gccs, mcfgthreads, wine, cutter,
imhex, jadx). Only small local derivations build on blaney-pc: ghidra-unsp, naken_asm and
the wrappers.

## Adding a language toolchain

Only when none of the existing shells fits. Five touch points, and the third is the one
that gets missed:

1. `modules/nixos/development/vibe-<lang>.nix` — copy `vibe-python.nix`. Declare
   `options.customConfig.profiles.development.vibe-<lang>.{enable,devShell}` and assign the
   `mkShell` only inside `config = lib.mkIf cfg.enable`. **Add nothing else to the system**;
   that is what makes step 3 free.
2. `modules/nixos/development/default.nix` — add the import.
3. **`hosts/gaming-pc/profiles.nix` — enable it.** `flake.nix` builds every devShell from
   `referenceHostConfig = self.nixosConfigurations."gaming-pc".config`, so a shell left
   disabled on gaming-pc **does not exist as a flake output at all** and every `.envrc`
   pointing at it fails. Verified: flipping these flags on gaming-pc leaves its
   `system.build.toplevel.drvPath` byte-identical, so it costs that host nothing — but it
   does mean **anyone trimming gaming-pc's dev profiles silently breaks Blaney's
   toolchain.** The comment in that file says so; keep it there.
4. `flake.nix` `devShells.x86_64-linux` — add the entry.
5. `hosts/blaney-pc/profiles.nix` (and `hosts/vm-blaney/profiles.nix`) — enable it, and add
   the name to `customConfig.programs.vibeProjects.shells` so the rules file lists it.

Keep each shell small and **check the packages are in the binary cache** before merging —
blaney-pc is a remote machine on ordinary internet, and a source build of a toolchain there
is hours:

```bash
p=$(nix eval --impure --raw .#nixosConfigurations.gaming-pc.pkgs.<attr>.outPath)
curl -s -o /dev/null -w '%{http_code}\n' "https://cache.nixos.org/$(basename $p | cut -c1-32).narinfo"
```

## Why root ownership works the way it does

Claude runs as `sudo claude` on this host (root's `settings.json` is the one
`modules/nixos/programs/claude-code.nix` generates), which has four consequences worth not
re-deriving. The first three were verified by experiment, not assumed:

- **git works in his project with no `safe.directory` entry.** git accepts a repo owned by
  another user when it is running as root *and* `SUDO_UID` is that owner's uid — which is
  exactly the case after `vibe` (as insideabush) execs `sudo claude`. Clear `SUDO_UID`, or
  set it to `0`, and the same command fails with `fatal: detected dubious ownership`.
- **Therefore `nix develop ~/nixos-config#vibe-python` works as root too** — the same check,
  in libgit2. But **a nested `sudo` resets `SUDO_UID` to 0** and it fails with
  `repository path ... is not owned by current user (libgit2 error code = 7)`. This is the
  same trap `wt_sudo_rebuild` in `modules/nixos/common/commands.nix` works around for
  `rebuild`. Never wrap either in another `sudo`.
- **Root has no git identity on this host** (`/root/.gitconfig` is hand-written and only
  exists on lando's machines), so `vibe` writes a repo-local `[user]` block at `git init`.
  git reads repo-local before any global config, which is what makes his commits come out
  as `insideabush <cblaney00@gmail.com>` rather than failing or being attributed to lando.
  Note a repo-local `safe.directory` would *not* work even if it were needed — git only
  honours that key in protected (system/global/command) scope.
- New files still start out root-owned. `~/projects` is added to
  `customConfig.programs.claudeCode.extraChownPaths` by the module itself, so the `Stop`
  and `PostToolUse` hooks chown the whole tree — but only at those points, which is why the
  rules tell the session to chown explicitly before handing something over to try.

direnv is the one thing that must run as *him*: its allow-hash is per-user, and his direnv
is in his own home-manager profile. Hence the absolute path in the rules:

```bash
sudo -u insideabush -H /etc/profiles/per-user/insideabush/bin/direnv allow .
```

It is purely a convenience for his own terminal. Claude uses `nix develop` explicitly.

### The branch trap

`nix develop ~/nixos-config#vibe-python` resolves against **whatever branch his config
checkout happens to be on**, and he switches branches himself with `branch-switch`. On a
branch predating this feature it fails with
`error: flake ... does not provide attribute 'devShells.x86_64-linux.vibe-python', ...` — meaningless
to him, and the tempting "fix" is for the session to start editing nixos-config from a vibe
project. The rules file names that exact error and the response: tell him to run `update`,
and do not touch the config. If this turns out to bite in practice, the fix is to bake the
toolchain into a `pkgs.buildEnv` referenced by store path from the `vibe` script, so no
flake resolution happens at run time at all.

## Packaging a finished app

This is the part that comes back here, as a `blaney/` branch and a PR lando merges. It does
**not** happen from a vibe session: the working directory there loads `~/projects/CLAUDE.md`,
not this repo's `CLAUDE.md`, so the `blaney/`-branch rules are not the ones in context. The
rules file tells the session to hand it back instead — "close this, run `ccn`, and say
package my `<name>` app". That reuses the proven path with the right rules loaded.

Then:

1. **Give the project its own GitHub repo first** — public, under his account
   (`cblaney00/<slug>`, as `cblaney00/glade` was), with the project's `main` pushed to it.
   Packaging is the moment a project stops being local-only; day-to-day vibe work still
   needs no remote. **Never vendor the source into `pkgs/<name>/src`** — this is the
   repo-wide standing rule in `CLAUDE.md` ("an app that isn't Nix lives in its own repo"),
   and it is what keeps his app history out of `nixos-config` and his apps reusable.
2. `pkgs/<name>/default.nix` — a normal derivation using
   `fetchFromGitHub { owner = "cblaney00"; repo = "<slug>"; rev = …; hash = …; }`. Get the
   hash by building once with `hash = lib.fakeHash;` and copying the real one from the
   mismatch error — that needs no network command beyond the build itself (a bare
   `nix-prefetch-url` was refused by the auto-mode classifier on blaney-pc during the glade
   PR). Record the repo in [docs/companion-repos.md](../companion-repos.md), and bump the pin
   there the same way as any other companion repo.
3. `customConfig.packages.homeManager` in `hosts/blaney-pc/apps.nix`.
4. A `.desktop` entry if it belongs in the Start menu, and a taskbar pin in
   `hosts/blaney-pc/home.nix` (`themes.xfcePanel.pinnedApps` / `themes.pinnedApps`) if he
   wants one — **ask him**, that is a visual decision.

**First one packaged: the Glade** (`~/projects/hud` → `pkgs/glade`). It is **vendored**:
`pkgs/glade/src` is a copy of the project's `glade/*.py`, because his repo has no remote and
pushing it somewhere would mean handing him credentials. Re-vendor by copying the files
over and bumping `version`; his project stays the place he and his sessions work on it.
It is not an app in the menu but his Hyprland desktop, wired up by
his Hyprland desktop (`hyprland.desktops.enabled = [ "glade" ]`) — see [theming.md](../theming.md#the-glade-theme).
Under XFCE he still runs it straight from the project folder.

Until then, running it out of the project folder with `nix develop ... --command` is the
normal way to use it.

## Verifying changes to this

`vibe` only exists where `customConfig.programs.vibeProjects.enable` is set, so it cannot be
rebuilt and exercised on gaming-pc. `vm-blaney` runs the same user with the same flag.

This is a **terminal** feature, so drive it over SSH — the QMP screenshot loop in
[test-vms-and-ci.md](../test-vms-and-ci.md) is for GUI work and buys nothing here.

```bash
nixos-rebuild build-vm --flake /home/lando/nixos-config#vm-blaney --impure
SCRATCH=/tmp/vmrun; mkdir -p "$SCRATCH"
NIX_DISK_IMAGE="$SCRATCH/disk.qcow2" \
QEMU_OPTS="-display none -qmp unix:$SCRATCH/qmp.sock,server=on,wait=off" \
  setsid ./result/bin/run-*-vm > "$SCRATCH/vm.log" 2>&1 &
ssh -p 2222 insideabush@127.0.0.1          # vm-common.nix forwards 2222 -> 22
```

The VM has no Claude auth, so shadow `claude` with a stub earlier on `PATH` that prints its
argv (`sudo` preserves `PATH` — there is no `secure_path` in this config's sudoers), and
feed the menu from a pipe: `printf '1\nSnake Game\n' | PATH="$HOME/stub:$PATH" vibe`.

Catch the shell-escaping class of bug without any VM at all, by building just the script:

```bash
nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); in
  builtins.head (builtins.filter (p: (p.name or "") == "vibe")
    f.nixosConfigurations.blaney-pc.config.environment.systemPackages)'
nix run nixpkgs#shellcheck -- -s bash /nix/store/...-vibe/bin/vibe
```

**Two things the VM cannot show**, to state in any PR: `hosts/vm-common.nix` sets
`wheelNeedsPassword = false` while blaney-pc prompts, so the VM does not prove the
single-password-prompt UX; and with no real Claude auth the trust dialog is never rendered,
only the `.claude.json` key that suppresses it.
