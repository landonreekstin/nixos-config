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
git repo in `~/projects/<slug>` that he commits to `main` freely. Only two things ever
come back here as a `blaney/` PR — a new language toolchain, and packaging a finished app.

**Non-Nix source lives in one of two places, never here:** local-only in its project folder
(the default — a new project has no remote), or its own GitHub repo on *his* account
(`cblaney00/<slug>`), pushed after every commit once it exists. This repo only ever
packages an app from that remote URL with a `fetchFromGitHub` pin, so an app must be on
GitHub before it can be packaged. A local-only project is not backed up anywhere — if that
disk dies it is gone, which is why the rules tell Claude to commit early and often.

## The layout

```
/home/insideabush/projects/
  CLAUDE.md              <- THE RULES. home-manager store symlink, immutable
  README.md              <- plain-English "type vibe", also home-manager
  snake-game/
    .vibe-project        title= slug= shell=   <- what makes this a vibe project
    .envrc               use flake ~/nixos-config#vibe-python
    CLAUDE.md            what THIS app is; points up at the rules
    .git/                local only, or pushed to github:cblaney00/<slug>
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

5. **Every session — resumed ones too — first catches his config up with `main`:** fetch;
   leave a dirty tree alone; fast-forward `main`, or rebase a `blaney/` branch onto
   `origin/main` and `--force-with-lease` it if it has an upstream (a conflict is aborted
   and handed to the config chat); then chown and `rebuild` if anything moved. It repeats when he
   comes back after a break. This is the one config action a vibe session takes, and it
   exists because `branch-switch` leaves him on `blaney/` branches that otherwise drift
   behind main for weeks — and `update` only pulls the branch, not main. It lives in the
   rules file, not the launch prompt, so `claude -c`/`-r` sessions do it too.

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
| Game mode (gamedev launcher, scaffold, `play-on-desktop`, shared game rules) | `modules/nixos/development/gamedev.nix`, `modules/home-manager/development/gamedev-rules.nix` — see [below](#game-projects) |

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

## Game projects

Where `customConfig.profiles.development.gamedev.enable` is on (blaney-pc), `vibe` also
offers **make a game of your own**. It is lando's `gd` setup from
[gamedev.md](../gamedev.md) — the awesome-gamedev-agent-skills plugin (router + 77 skills)
and Godot / LÖVE / pygame-ce / Node — applied to a vibe project. It mirrors the
reverse-engineering mode point for point:

- **Marker**: `kind=game` (and `shell=gamedev`) in `.vibe-project`; the pick list labels
  these `(game)`.
- **Rules**: a "Game projects" section in `~/projects/CLAUDE.md`, emitted only when the
  profile is on, placed *before* the RE section (which claims everything to the end of
  the file) and closed with an end-of-section line. Its second half is
  `gamedev-rules.nix`, the same text as lando's `~/gamedev/CLAUDE.md`.
- **Every launch goes through `gamedev.launcher`**, resumed chats included, as
  `sudo <launcher> --settings <glade panel hooks> [-c|-r|prompt]` — so game chats get the
  Glade Claude panel like plain app chats do.
- **Layout** from `gamedev.scaffold` (`assets/ docs/` + engine-aware `.gitignore`), plus
  the vibe `.gitignore` lines.
- **He plays it on his own screen**: the session is root, so the rules require
  `play-on-desktop insideabush <cmd>`, which runs the game as him inside his desktop
  session. Claude checks its own work headless first (`xvfb-run` screenshot).
- `workspace.enable = false` on blaney-pc hides `gd` and `~/gamedev`, for the same reason
  as `re`.

Everything the profile pulls in is in cache.nixos.org (unstable godot, love, pygame-ce,
libresprite …); only the plugin copy and the small wrappers build locally.

### Games shared with lando (prin-rpg)

`customConfig.profiles.development.gamedev.sharedProjects` (set in each host's
`profiles.nix`) lists lando's game repos that insideabush works on too. Each one adds a top
menu entry, "Work on <title> with Lando". On first use it clones the repo over HTTPS as him,
using his `gh` login, into `~/projects/<name>`. It writes a `.vibe-project` with
`kind=game` and `shared=<owner/repo>`, which stays out of the repo through
`.git/info/exclude`. After that the game also shows in the "already started" list as
"(game, with Lando)".

These are **not** his repos, so the "commit to main freely" rule doesn't apply. Instead:
- On every open, `vibe` sets the clone's `core.hooksPath` to `gamedev.mainGuardHooks`, git
  hooks that refuse a commit on `main` and a push to `main`. That's the only enforcement:
  the repo is private on a free GitHub plan, so there are no server-side branch rules, and
  a collaborator on a personal repo always has write access.
- The binding rules are in the project's own `CLAUDE.md` ("Working together: git and PRs").
  Every clone reads the same text: `blaney/` branches, a PR, stop, and lando merges.
  The "Games shared with lando" part of `~/projects/CLAUDE.md` says that this overrides
  the commit-to-main rules, so a resumed chat knows it too.
- Pushes and `gh` run as him (`sudo -u insideabush -H ...`), because the session is
  root.
- **His look-and-feel calls are recorded.** The project's `docs/style.md` holds the
  current style and a dated direction log of every call he or lando makes, in their own
  words. Sessions read it before any visible change and update it in the same commit,
  and the PR flags a "Style conflict" when one of you overrides the other. The rules are
  in the project's `CLAUDE.md` ("Look and feel") and repeated in his game rules.

**"Play it"** appears in the per-game menu of every game project, shared or his own,
that has a `project.godot` or `main.lua`. It starts the game on his screen as him, with no
Claude chat, playing whatever branch his copy is on. Godot gets a headless `--import`
first: the game's script classes are registered in the gitignored `.godot/`, so a fresh
clone or newly pulled scripts fail with "Could not find type …" without it.

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
rules file tells the session to hand it back instead — "close this, run `vibe`, choose
"Change or fix something on your computer", and say
package my `<name>` app". That reuses the proven path with the right rules loaded.

Then:

1. **Give the project its own GitHub repo first** — public, under his account
   (`cblaney00/<slug>`, as `cblaney00/glade` was), with the project's `main` pushed to it.
   Skip this if the project already has one. Day-to-day vibe work still
   needs no remote. **Never vendor the source into `pkgs/<name>/src`** — this is the
   repo-wide standing rule in `CLAUDE.md` ("an app that isn't Nix lives in its own repo"),
   and it is what keeps his app history out of `nixos-config` and his apps reusable.
2. `pkgs/<name>/default.nix` — a normal derivation using
   `fetchFromGitHub { owner = "cblaney00"; repo = "<slug>"; rev = …; hash = …; }`. Get the
   hash by building once with `hash = lib.fakeHash;` and copying the real one from the
   mismatch error — that needs no network command beyond the build itself (a bare
   `nix-prefetch-url` was refused by the auto-mode classifier on blaney-pc during the glade
   PR). Give the package a `localSrc ? null` argument used in place of the fetch (as
   `pkgs/glade` does), pass `(import ../pkgs/vibe-local-src.nix customConfig "<name>")` at
   every `callPackage`, and add the app to `vibeProjects.localApps` in
   `hosts/blaney-pc/apps.nix`, so his machine keeps running his project folder. Record the
   repo in [docs/companion-repos.md](../companion-repos.md); from then on the pin moves only
   for a release, as described there.
3. `customConfig.packages.homeManager` in `hosts/blaney-pc/apps.nix`.
4. A `.desktop` entry if it belongs in the Start menu, and a taskbar pin in
   `hosts/blaney-pc/home.nix` (`themes.xfcePanel.pinnedApps` / `themes.pinnedApps`) if he
   wants one — **ask him**, that is a visual decision.

**First one packaged: the Glade** (`~/projects/glade` → `github:cblaney00/glade` →
`pkgs/glade`). `pkgs/glade` pins the repo with `fetchFromGitHub` (its `glade/` folder is
the program); bump it as in [companion-repos.md](../companion-repos.md#glade). His project
stays the place he and his sessions work on it, and `vibe` lists it first as **"Work on
your Glade"** (any project whose `origin` is a repo named `glade`).
It is not an app in the menu but his Hyprland desktop, wired up by
his Hyprland desktop (`hyprland.desktops.enabled = [ "glade" ]`) — see [theming.md](../theming.md#the-glade-theme).
Under XFCE he still runs it straight from the project folder.

Until then, running it out of the project folder with `nix develop ... --command` is the
normal way to use it.

## Packaged apps run from the project folder; the pin is a release

Once packaged, an app is built on blaney-pc from `~/projects/<folder>`, not from its pin
(`customConfig.programs.vibeProjects.localApps`, resolved by `pkgs/vibe-local-src.nix`).
So a vibe session gets a change into the installed app by committing and running
`rebuild` in the config, with no config edit, branch or PR. That is the second, and last,
reason a project session may go into the config (the first is the catch-up). The pin is
the version lando gets, and moves only when insideabush asks for a release, in a PR of its
own: [companion-repos.md](../companion-repos.md#insideabushs-apps-the-pin-is-a-release).

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
