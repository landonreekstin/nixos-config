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

## Phase 2 — gather his files under `blaney/` (this repo)

`git mv` into a top-level `blaney/` laid out like his future repo root, so phase 3 is a
mechanical `git filter-repo`:

| To `blaney/…` | From |
|---|---|
| `hosts/{blaney-pc,justus-pc,vm-blaney}` | `hosts/` |
| `modules/nixos/blaney-commands.nix` | `modules/nixos/common/` (drop from `common/default.nix`) |
| `modules/nixos/vibe-projects.nix`, `modules/home-manager/vibe-projects.nix` | `programs/`, `home-manager/development/` |
| `modules/nixos/{vibenote,remote-admin,net-watch}.nix` | `programs/`, `services/` |
| `modules/home-manager/{release-notes,shutdown-guard,rebuild-shutdown-notify}.nix` | `home-manager/services/` |
| `modules/home-manager/desktops/glade/` | `home-manager/hyprland/desktops/glade/` (as rehearsed) |
| `pkgs/{glade,vibenote,vibe-local-src.nix}` | `pkgs/` |
| `docs/hosts/blaney-*.md`, `docs/runbooks/blaney/`, `docs/runbooks/blaney-sops-setup.md` | `docs/` |
| `secrets/blaney-pc*.yaml` | `secrets/` |

- Move option declarations with their modules: `releaseNotes` and `shutdownGuard` are
  declared in `common/home-manager.nix`.
- Add `blaney/modules/{nixos,home-manager}/default.nix` importers; his hosts import the
  NixOS one and add the HM one via `home-manager.sharedModules`.
- Fix repo-relative paths (`release-notes.nix` `runbookDir`, hosts' `sopsFile`s,
  `vibe-local-src.nix` callers).
- Stays in the library: gamedev, reverse-engineering, windows7-xfce, `claude-code.nix`,
  `vibe-python`/`vibe-web` devShells, r62d and f-117 (gaming-pc/mini-server use them) and
  the `release-pins` CI job for those.
- **Verify:** blaney-pc, justus-pc, vm-blaney drvPaths identical to before; all other hosts
  unchanged (nix-diff for the four leak hosts); CI green.

## Phase 3 — create `cblaney00/nixos-config`

1. Scratch clone: `git filter-repo --path blaney/ --path-rename blaney/:`.
2. Add: `flake.nix` (`lib.url = "github:landonreekstin/nixos-config"`, `nixpkgs` and
   `home-manager` follow `lib/…`, hosts via `lib.lib.mkSystem`, re-export `lib`'s
   `devShells` so `use flake ~/nixos-config#vibe-python` etc. keep working);
   `.sops.yaml` (blaney-pc host key + a new admin age key he owns; lando's key kept as
   break-glass, his to remove; `sops updatekeys`); `CLAUDE.md` built from
   `docs/hosts/blaney-pc.md` (he owns `main` and merges his own verified PRs; no
   `blaney/` prefix; library changes = PR to landonreekstin/nixos-config; release notes
   stay); `.github/workflows/check.yml` (eval his 3 hosts) and `update-lib.yml` (weekly
   `DeterminateSystems/update-flake-lock` on `lib`, auto-merge when green).
3. Set `customConfig.system.configRepo = "cblaney00/nixos-config"` on his hosts; update the
   `gh api repos/landonreekstin/...` and "let lando merge" wording in `blaney-commands.nix`
   / `vibe-projects.nix` and the `vibe` / `blaney-todo` prompts.
4. Blaney (his `gh`, on blaney-pc) creates the public repo, pushes, adds `landonreekstin`
   as collaborator.
- **Verify:** drvPaths from his repo equal phase 2's, apart from the intended wording diff.

## Phase 4 — cut blaney-pc over (on the machine)

`mv ~/nixos-config ~/nixos-config.monorepo`, clone his repo to `~/nixos-config`, chown,
`rebuild`. Check: `vibe` (config chat + a project), `blaney-todo` walk-away run opens a PR
on **his** repo, `add-notes`/`work-notes`, `update`, `update-shutdown`, the auto-update
timer, release-notes popup, glade desktop + dock, shutdown guard, Win7 XFCE session,
`branch-switch`, sops/WG homelab peer. Add a release note about the move. justus-pc the
same whenever reachable (its sops key is still a placeholder).
Rollback: move `~/nixos-config.monorepo` back and `rebuild`.

## Phase 5 — clean up the library (after phase 4 is verified)

Delete `blaney/` and his hosts from `flake.nix`; drop them from `check.yml`'s host list,
`flake-updater.nix`'s default hosts, `testvm`'s `blaney` case and `.sops.yaml`. Add a
`continue-on-error` downstream CI job:
`nix eval github:cblaney00/nixos-config#nixosConfigurations.<h>.config.system.build.toplevel.drvPath --override-input lib .`
for blaney-pc and justus-pc. Rewrite CLAUDE.md (drop blaney-pc guidelines, blaney
commands, `--admin`/`blaney/` rules, his doc-table rows; add "Downstream consumers"),
update `docs/companion-repos.md`, revisit the `protect-main-merges` ruleset, and repoint
the blaney-pc memory notes at his repo.
