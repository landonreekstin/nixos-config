<!-- ~/nixos-config/docs/flake-updates.md -->
> **Read this when**: an `update/*` branch or weekly-update PR needs blocking, fixing,
> or explaining, or when the beta-host (gaming-pc) tracking behaviour is in question.

# Automated Weekly Flake Updates (CI/CD Pipeline)

Flake updates are automated via a systemd service on `optiplex-nas` that runs every Monday at 03:00.

## How it works

1. NAS creates branch `update/YYYY-WNN`, runs `nix flake update`, builds all 9 hosts, opens a GitHub PR
2. **gaming-pc** (`betaTesterHost = true`) automatically tracks the latest `update/*` branch on the next `update` — it receives the update one week before everyone else
3. On the **following Monday's run** (about 6 days later, since the check runs before the new PR is opened), the NAS auto-merges the prior week's PR if no `update-blocked` label is present. Auto-merge uses `--admin` so it bypasses the `protect-main-merges` ruleset.
4. All other hosts pick up the update on their next `update` after the merge

## Blocking a bad update

If a flake update causes a runtime issue (e.g., broken NVIDIA driver, broken audio) that passes eval but breaks the live system:

1. Go to the open `chore(flake): weekly update YYYY-WNN` PR on GitHub
2. Add the **`update-blocked`** label
3. The NAS will NOT auto-merge while this label is present
4. To roll back gaming-pc immediately: `git checkout main && rebuild`
5. When you have a fix, push it to the `update/*` branch, remove the label — the next Monday run will auto-merge

## Manual trigger

To manually run the updater on optiplex-nas:
```bash
sudo systemctl start flake-updater
journalctl -u flake-updater -f
```

## Beta host behavior

On gaming-pc, running `update` when an `update/*` branch exists on remote will automatically switch to it. When no update branch exists (post-merge), `update` falls back to main. This is transparent — no user action needed.

## Desktop hosts: the shutdown guard

`customConfig.services.autoUpdate` assumes the host is *on* when its timer fires. On a
headless server that is a given; on a desktop it is not, and `persistent = false` (the
right setting there — it stops a surprise rebuild+poweroff on the next boot) means a
missed window is simply lost until the following week. blaney-pc makes this worse with
`shutdownAfterRebuild = true`: the machine is *supposed* to end up off, so "it was off"
looks normal and nobody notices the update never ran.

`customConfig.homeManager.services.shutdownGuard.enable` closes that gap. It installs a
`shutdown-guard` command that reads `nixos-auto-update.timer`'s next elapse and, only when
that is within `warnWithinHours` (default 12), shows a GTK dialog offering **Shut down
anyway** / **Update now, then shut down** / **Cancel**. Outside the window — or on a host
with no auto-update timer — it exits silently and instantly. Every shutdown path the user
can reach runs it first; see [hosts/blaney-pc.md](hosts/blaney-pc.md#the-shutdown-guard).

The "update now" button runs **`update-shutdown`**, which is also a plain CLI command on
every host: git pull → rebuild → power off, i.e. the weekly run on demand. (Do not confuse
it with `rebuild-shutdown`, which rebuilds the flake already on disk and never fetches.)

## For Claude: how to handle common requests

**"Approve the update" / "let it merge"** — do nothing. The NAS auto-merges on the following Monday's run automatically. There is no action needed; manually merging via `gh pr merge` is wrong and bypasses the soak period.

**"Block the update" / "don't merge this"**
```bash
# Find the open update PR
gh pr list --repo landonreekstin/nixos-config --label flake-update
# Add the block label (use the PR number from above)
gh pr edit <PR_NUMBER> --repo landonreekstin/nixos-config --add-label "update-blocked"
```

**"Fix the update" / "push a fix to the update branch"**
```bash
# Find the current update branch
git branch -r --list 'origin/update/*' | sort -V | tail -1
# On gaming-pc, the branch is already checked out; on other machines, check it out:
git checkout -B update/YYYY-WNN origin/update/YYYY-WNN
# Make the fix, rebuild/verify, then:
git push origin update/YYYY-WNN
# After confirming the fix works, remove the block label if present:
gh pr edit <PR_NUMBER> --repo landonreekstin/nixos-config --remove-label "update-blocked"
```

**"Roll back gaming-pc"** — gaming-pc is the only host that auto-tracks the update branch:
```bash
git checkout main && rebuild
```

---


## Release upgrades (25.11 → 26.05 and the next one)

A release upgrade is **not** a weekly update and must not be run as one. The weekly
pipeline moves inputs *within* a release; this moves the release itself, which changes the
boot path. Everything above about `update/*` branches and auto-merge works against you here.

Do it on **gaming-pc** (the beta host, and the only one where a display can be checked).

**1. Pause the unattended hosts first, in a separate PR that lands on the current release.**
`blaney-pc`, `optiplex-nas` and `mini-server` all pull `main` and `nixos-rebuild switch` on
a timer. Set `customConfig.services.autoUpdate.enable = false` on all three, merge it, and
confirm each host has picked it up **before** the upgrade PR merges. blaney-pc is the sharp
edge — `shutdownAfterRebuild = true` means its *next power-on* would be its first boot on
the new release, unattended, at a non-technical user's house. optiplex-nas has no WoL and
no IPMI. Revert this PR only after every host has been rebooted onto the new release.

**2. Name the branch `feat/nixos-XX.YY`, never `update/*`.** gaming-pc auto-tracks any
`update/*` branch and the NAS auto-merges the previous one on the following Monday. A
`feat/` prefix keeps both automations out of it.

**3. Bump two lines and relock.** `nixpkgs` and `home-manager` (`release-XX.YY`) move
together. Every other input either `follows` nixpkgs or floats.

**4. Gate on builds, not evals.** `nix eval` type-checks; it does not compile. The 26.05
upgrade's two worst findings — a `buildEnv` collision that made `optiplex` unbuildable, and
`gamescope-kbm` failing on a new libinput enum — were both invisible to eval, and the
optiplex one had been broken on `main` for some time because **CI only evaluates hosts; its
`build` job covers the aerotheme/openrazer derivations, not full toplevels**. Build every
configuration:
```bash
for host in $(NIXPKGS_ALLOW_UNFREE=1 nix eval --impure --raw \
    --expr 'builtins.concatStringsSep " " (builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations)'); do
  printf "%-16s " "$host"
  NIXPKGS_ALLOW_UNFREE=1 nix build --impure ".#nixosConfigurations.$host.config.system.build.toplevel" \
    --no-link >/dev/null 2>&1 && echo OK || echo FAIL
done
```

**5. Expect the theme pins to move.** `aerothemeplasma` is versioned against *Plasma*, not
against itself, so its rev has to move whenever nixpkgs moves Plasma — and upstream has
since split the KWin half into separate repos. See the comment block at the top of
`modules/nixos/themes/aerothemeplasma/aerothemeplasma.nix`; it records which rev pairs with
which Plasma and why the decoration and smodglow must stay on the same rev.

**6. stateVersion never moves.** It records the install, not the channel. The same goes for
Home Manager defaults that key off it — pin the legacy behaviour explicitly rather than
letting a new default rewrite `$HOME` on every host.

**7. A `switch` proves nothing about the boot path.** 26.05 made systemd stage-1 initrd the
default and swapped `dbus` for `dbus-broker`; after switching, `dbus-broker.service` is
still running the old `dbus-daemon` process and NVIDIA userspace is mismatched against the
loaded module. **Reboot gaming-pc** and only then check `nvidia-smi`, the Plasma and
Hyprland sessions, and a game. Soak for several days before merging.

**8. Roll out most-recoverable first**, each a deliberate rebuild *and* reboot: mini-server
(reachable via optiplex-fw) → optiplex-nas (physical access only; re-check the `/mnt/private`
LUKS unlock and the CI runner afterwards) → the desktops → blaney-pc last, in person.

Rollback is the previous generation in the systemd-boot menu.
