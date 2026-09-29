<!-- ~/nixos-config/docs/parallel-sessions.md -->
> **Read this when**: more than one session (you, or a Claude session, or both) is working
> on this config at the same time, or a `rebuild` was REFUSED because another worktree owns
> the live system.

# Parallel Sessions and Worktrees

Several tasks can be edited at once — one git worktree each — but **a machine can only have
one configuration activated at a time**. Those two facts are what this document reconciles.

## Why the shared checkout breaks down

Before worktrees, every session shared `~/nixos-config`. Because CLAUDE.md makes
`rebuild` + verify mandatory *before* commit, and `rebuild` was pinned to that one
directory, every task had to pass through the same working tree. The result, repeatedly:

- one session's `git checkout` moved HEAD under another session mid-task;
- `git status` showed three tasks' files at once, so `git add -A` swept up a stranger's
  half-finished work;
- a session verified a rebuild that had actually activated *someone else's* edits, and
  then committed on the strength of it.

## The layout

```
~/nixos-config/                        the main checkout — always exists, tracks main
~/nixos-config-worktrees/
  ├── retire-aerothemeplasma/          one directory per in-flight task
  ├── iw4x-payload-cache/
  └── hyprsunset-solar/
```

All worktrees share the one `.git`, so branches, refs, fetches and the object store are
common. Only the checked-out files and the index are per-worktree — which is exactly the
part that was colliding.

## The commands

```bash
wt                      # list worktrees: path, branch, uncommitted count, who owns the system
wt new fix/foo          # create ~/nixos-config-worktrees/foo on branch fix/foo
wt new fix/foo --from origin/main --name foo-alt
wt rm foo               # remove it (refuses while it has uncommitted work)
wt status               # who owns the live system, since when, at which commit
```

`wt new` bases a brand-new branch on `origin/main` (not on whatever the main checkout
happens to be sitting on). An existing local or `origin/` branch is checked out as-is.

## Rebuild ownership

`rebuild`, `rebuild-test` and `upgrade` build **the worktree your shell is in**, resolved
from `git rev-parse --show-toplevel`. Standing anywhere that is not a worktree of this repo
falls back to `~/nixos-config`, as before.

Exactly one worktree owns the live system at a time. That owner is recorded in
`/var/lib/nixos-config/active-worktree` after each successful activation. From any other
worktree, `rebuild` refuses:

```
REFUSED: gaming-pc's live system is owned by:
    /home/lando/nixos-config-worktrees/iw4x-payload-cache
    branch feat/iw4x-payload-cache  (activated 14:02)

  You are in:
    /home/lando/nixos-config-worktrees/hyprsunset-solar
    branch fix/hyprsunset-solar-schedule

  Verification here would be testing THAT branch's code.
  Run 'rebuild --take' to move ownership to this worktree.
```

This is a hard gate rather than a warning **because the repo's commit rule depends on it**:
"rebuilt and verified" is only a true statement if the code you verified is the code you are
about to commit. From a non-owning worktree it is not.

`rebuild --take` moves ownership here in one step. Taking it is normal and cheap — the point
is that it is deliberate, and that the other session's next `rebuild` will tell it what
happened rather than silently interleaving.

Two further guards:

- **A lock** (`/var/lib/nixos-config/rebuild.lock`) serialises activations, so two
  simultaneous `nixos-rebuild switch` runs wait instead of racing. A lock that cannot be
  taken never blocks the rebuild — the machine must always be rebuildable.
- **A staleness check.** The record stores the `/run/current-system` it produced. The weekly
  auto-update unit and any hand-run `nixos-rebuild` change the live system without going
  through `rebuild`, so when those no longer match, `wt status` and `rebuild` say the record
  is stale instead of quietly asserting a false owner.

## Running several sessions

Start each session **in its own worktree** (`cd` there before launching `claude`). The
session inherits that worktree as its working directory, so its edits, `git status`,
`git add` and commits are confined to its own task.

A session that does not own the live system is not stuck — it can still do everything except
activate:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix eval --impure \
  .#nixosConfigurations.$(hostname).config.system.build.toplevel.drvPath
```

An eval (or a full `nix build` of the toplevel) needs no ownership and catches everything
short of runtime behaviour. The usual shape is: several sessions edit and eval in parallel,
and they take the system one at a time for the verify step.

For changes that can only be *seen* to work, `testvm sandbox` is the other way to verify
without taking the machine — see [test-vms-and-ci.md](test-vms-and-ci.md).

## The libgit2 ownership trap

`rebuild` runs `nixos-rebuild` under `sudo`, so nix evaluates the flake **as root out of a
checkout owned by `lando`**. nix reads the git tree with libgit2, which refuses that:

```
error: opening Git repository "/home/lando/nixos-config-worktrees/foo":
       repository path '...' is not owned by current user (libgit2 error code = 7)
```

libgit2 accepts it when the *sudo-invoking* user owns the directory, which it learns from
`SUDO_UID`. So:

- **lando running `rebuild`** → the inner sudo sets `SUDO_UID=lando`, the repo is lando's,
  it works. This path was never broken.
- **a Claude session** runs as root already (`sudo claude`), so its inner sudo is a *nested*
  one and resets `SUDO_UID=0` → the identical command fails.

`rebuild`, `rebuild-test` and `upgrade` therefore invoke
`sudo env SUDO_UID=<owner of the flake dir> nixos-rebuild …`, which states something true
and makes both paths behave the same.

Two things worth knowing if this resurfaces:

- An **exact** `safe.directory` entry also satisfies libgit2. Hand-written entries in root's
  `~/.gitconfig` for `~/nixos-config` (and `~/nixos-config-aero`) were quietly doing that for
  years, which is why the main checkout worked as root and a newly created worktree did not —
  undeclared state producing an inconsistency nobody could see.
- The **trailing-glob** form (`/home/lando/nixos-config-worktrees/*`) that plain `git`
  accepts is **ignored by nix's libgit2**. It cannot be used to cover a directory of
  worktrees, so don't reach for it as a fix.

Note this is separate from the plain-`git` "dubious ownership" error, which the shell helpers
handle with `git -c safe.directory='*'`.

## Housekeeping

- `wt rm` refuses to remove the worktree that owns the live system: the running config would
  have no source tree behind it. Rebuild from elsewhere first.
- Worktrees are cheap (one checkout each, shared object store) but not free — remove them
  once the PR is merged.
- `flake-update` updates the lock file of the worktree you are in, not the main checkout.
- Nothing here changes the weekly flake-update automation, which operates on the NAS's own
  clone. See [flake-updates.md](flake-updates.md).
