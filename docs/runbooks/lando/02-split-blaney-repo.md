# Split Blaney's hosts into his own repo

Runs on: gaming-pc (phases 1–3, 5), blaney-pc in person or over `ssh blaney` (phase 4).
Agreed with lando 2026-11-19/20. Work one phase at a time, each in its own `wt new` tree
and its own PR, landed right after a Monday auto-merge (every phase touches `flake.nix`
or many hosts, so it conflicts with the weekly `update/*` PR otherwise). Delete this
runbook when phase 5 is merged.

## Goal

- `landonreekstin/nixos-config` stays the **module library + lando's hosts**, and exports
  `lib.mkSystem` (see docs/architecture.md, "Downstream host repos").
- New **public** `cblaney00/nixos-config` holds `blaney-pc`, `justus-pc`, `vm-blaney`, the
  modules only his hosts use, his docs, runbooks and secrets. It **follows the library's
  nixpkgs/home-manager pins**. He owns its `main`. lando is a collaborator and keeps
  remote-admin SSH. Library changes still reach us as PRs from him, like now.
- Safety net: his repo's CI evaluates his hosts on a weekly `lib` lock-bump PR (a broken
  library change becomes a red PR, never a broken machine); our CI evaluates his hosts
  against each library PR, informational only.
- **Nothing is deleted from the library until blaney-pc runs from his repo and is verified.**

## Phase 1 — library is consumable  ✅ PR `feat/library-mksystem`

`lib.mkSystem` + `nixosModules.default`; `system.configRepo`;
`homeManager.claudeShellShortcuts` (replaces the `insideabush` name check in bash.nix);
`hyprland.desktops.extra` + the `hyprDesktopLib` module arg (HM side in
`hyprland/desktops.nix`, NixOS side `meta.nix` lookup in `desktop/hyprland.nix`).
All drvPaths identical (bar the four wallpaper source-leak hosts, see architecture.md).

**Rehearsed:** moving `desktops/glade/` to `blaney/modules/home-manager/desktops/glade`,
swapping `(import ../lib.nix { inherit lib; })` for the `hyprDesktopLib` arg in its five
files, registering it via `desktops.extra.glade` on blaney-pc and vm-blaney, and pointing
the three `claude-panel.nix` importers (`common/blaney-commands.nix`,
`programs/vibe-projects.nix`, `home-manager/development/vibe-projects.nix`) at the new
path gave **byte-identical** blaney-pc and vm-blaney drvPaths.

## Phase 2 — decouple in place  ✅ PR `feat/blaney-split-decouple`

**His files keep their exact paths** (no `blaney/` staging dir). blaney-pc auto-pulls
`main`, and its commands read `docs/runbooks/blaney/` and `docs/hosts/blaney-pc.md` by
repo-relative path at runtime, so moving them before the cutover would break his live
sessions. A staging dir would also put every file one level deeper than in his repo.
Instead this phase cut every link between his files and the library, in place:

- His modules left the library importers. `modules/blaney-nixos.nix` imports them, plus
  `modules/nixos/blaney-hm-options.nix`, and loads `modules/blaney-home.nix` through
  `home-manager.sharedModules`. blaney-pc and vm-blaney import it; justus-pc needs none of it.
- The `rebuildShutdownNotify` / `releaseNotes` / `shutdownGuard` option declarations moved
  out of `common/home-manager.nix` into `blaney-hm-options.nix`.
- His files reach library files only through `"${inputs.self}/…"` imports of Nix code:
  - `modules/nixos/default.nix` and `hosts/vm-common.nix`
  - `pkgs/vibe-local-src.nix`, `pkgs/worldmonitor`
  - `gamedev-rules.nix` and `reverse-engineering-rules.nix`
  - glade uses the `hyprDesktopLib` arg; `claude-panel.nix` now takes `inputs`
- The two shared assets he uses (`f15-animation-240x67.dur`, `f-15-satellite.jpg`) were
  **copied** byte-identically into `assets/blaney/`. A `"${inputs.self}/…"` string would
  have leaked the whole repo source into his system.
- Library code tolerates his options being absent: `vibe-local-src.nix` uses
  `vibeProjects or { enable = false; }`, and glade uses `shutdownGuard.enable or false`.
- glade is registered via `desktops.extra.glade` on his hosts. The same directory is still
  found by readDir until phase 5, and the two collapse into one.

**Proof:**
- All 12 configs evaluate.
- Lando's hosts are byte-identical (bar the four wallpaper leaks, nix-diff).
- justus-pc is identical.
- blaney-pc and vm-blaney differ only in **order**: `system-path`, `home-manager-path` and
  `nixos-tmpfiles.d` list the same items in a new merge order. Building both versions:
  - `system-path` hashes identical
  - `home-manager-path` differs only in `lib/fontconfig/cache` filenames, which are keyed
    by the output's own store path
  - tmpfiles has the same lines, with the dir-before-link order kept
- Leak check: no `.drv` in blaney-pc, vm-blaney or justus-pc mentions the repo source path.
  The optiplex positive control finds its one.

**His files = the Phase 3 extraction list:**
- `hosts/{blaney-pc,justus-pc,vm-blaney}/`
- `modules/blaney-{nixos,home}.nix`, `modules/nixos/blaney-hm-options.nix`
- `modules/nixos/common/blaney-commands.nix`
- `modules/nixos/programs/{vibe-projects,vibenote,keyripple}.nix`
- `modules/nixos/services/{remote-admin,net-watch}.nix`
- `modules/home-manager/development/vibe-projects.nix`
- `modules/home-manager/services/{release-notes,shutdown-guard,rebuild-shutdown-notify}.nix`
- `modules/home-manager/hyprland/desktops/glade/`
- `pkgs/{glade,vibenote,keyripple}/`
- `assets/blaney/`
- `docs/hosts/blaney-{pc,vibe-projects}.md`, `docs/runbooks/blaney/`, `docs/runbooks/blaney-sops-setup.md`
- `secrets/blaney-pc{,-admin,-forgejo}.yaml`

Stays in the library:
- gamedev, reverse-engineering (+ their `*-rules.nix`), windows7-xfce, `claude-code.nix`
- the `vibe-python`/`vibe-web` devShells
- `vibe-local-src.nix`
- r62d and f-117 (gaming-pc and mini-server use them), and the `release-pins` CI job

## Phase 3 — create `cblaney00/nixos-config`

1. Scratch clone of the Phase 2 branch, then
   `nix run nixpkgs#git-filter-repo -- --path <each item above>`. No renames: relative
   paths between his own files stay valid.
2. Add:
   - **`flake.nix`**: `lib.url = "github:landonreekstin/nixos-config"`; `nixpkgs` and
     `home-manager` follow `lib/…`; hosts via `lib.lib.mkSystem`; re-export `lib`'s
     `devShells` so `use flake ~/nixos-config#vibe-python` etc. keep working.
   - **`.sops.yaml`**: blaney-pc host key, plus a new admin age key he owns, plus lando's
     key kept as break-glass (his to remove); then `sops updatekeys`.
   - **`CLAUDE.md`**, built from `docs/hosts/blaney-pc.md`: he owns `main` and merges his
     own verified PRs; no `blaney/` prefix; library changes go to a PR on
     landonreekstin/nixos-config; release notes stay.
   - **CI**: `.github/workflows/check.yml` (eval his 3 hosts) and `update-lib.yml` (weekly
     `DeterminateSystems/update-flake-lock` on `lib`, auto-merge when green).
3. At cutover, not in the no-op proof:
   - set `customConfig.system.configRepo = "cblaney00/nixos-config"` on his hosts
   - update the `gh api repos/landonreekstin/...` and "let lando merge" wording in
     `blaney-commands.nix` / `vibe-projects.nix` and the `vibe` / `blaney-todo` prompts
4. Blaney (his `gh`, on blaney-pc) creates the public repo, pushes, and adds
   `landonreekstin` as collaborator.
- **Verify:** drvPaths from his repo equal Phase 2's.

## Phase 4 — cut blaney-pc over (on the machine)

`mv ~/nixos-config ~/nixos-config.monorepo`, clone his repo to `~/nixos-config`, chown,
`rebuild`. Check: `vibe` (config chat + a project), `blaney-todo` walk-away run opens a PR
on **his** repo, `add-notes`/`work-notes`, `update`, `update-shutdown`, the auto-update
timer, release-notes popup, glade desktop + dock, shutdown guard, Win7 XFCE session,
`branch-switch`, sops/WG homelab peer. Add a release note about the move. justus-pc the
same whenever reachable (its sops key is still a placeholder).
Rollback: move `~/nixos-config.monorepo` back and `rebuild`.

## Phase 5 — clean up the library (after phase 4 is verified)

Delete every file in the Phase 2 extraction list (incl. glade, so readDir stops finding it) and his hosts from `flake.nix`; drop them from `check.yml`'s host list,
`flake-updater.nix`'s default hosts, `testvm`'s `blaney` case and `.sops.yaml`. Add a
`continue-on-error` downstream CI job:
`nix eval github:cblaney00/nixos-config#nixosConfigurations.<h>.config.system.build.toplevel.drvPath --override-input lib .`
for blaney-pc and justus-pc. Rewrite CLAUDE.md (drop blaney-pc guidelines, blaney
commands, `--admin`/`blaney/` rules, his doc-table rows; add "Downstream consumers"),
update `docs/companion-repos.md`, revisit the `protect-main-merges` ruleset, and repoint
the blaney-pc memory notes at his repo.
