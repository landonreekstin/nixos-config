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

