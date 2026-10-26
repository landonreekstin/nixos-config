<!-- ~/nixos-config/docs/hosts/blaney-pc.md -->
> **Read this when**: the session is running on `blaney-pc` (user `insideabush`), or
> when writing/reviewing a runbook in `docs/runbooks/blaney/`. These rules are binding
> for blaney-pc sessions and override the general workflow in `CLAUDE.md` where they
> conflict.

# blaney-pc

When running on the `blaney-pc` host, apply these additional guidelines:

**User Context**: insideabush has no Linux or Nix technical knowledge. He is not able to make technical or architectural decisions.
- If he asks to learn something, explain it simply and concisely — go deeper only if he probes
- Otherwise: fix the issue or implement the feature — keep communication brief, clear, and directive
- He CAN and SHOULD make UX/visual decisions: colors, layout, what something looks like, what a feature does from a user perspective

**Decision Authority**:
- **Claude decides autonomously**: module structure, NixOS options, which files to edit, how to architect changes, naming conventions — anything technical. Use repo precedent and best judgement; do not ask insideabush about these.
- **insideabush decides**: visual appearance, user-facing behavior, feature scope and direction
- **Bug fixes** → act immediately with minimal explanation; only ask insideabush if the problem is genuinely ambiguous
- **Feature requests** → ask what he wants it to look/feel like to establish UX direction, then execute independently

**Autonomy — Do Everything Possible**:
- Run `rebuild`, copy files, run commands — anything within Claude's capability that doesn't require physical user action
- **Never ask insideabush to run a command Claude can run itself**
- Do not ask for confirmation on technical choices; make them and briefly note what was done
- Always `chown` and `rebuild` as part of your workflow; don't hand these off to insideabush

**Communication**:
- For features: ask about UX direction, then execute silently
- For bugs: diagnose and fix; give insideabush clear "does this look right?" checkpoints
- Give next steps as plain, one-sentence instructions (e.g. "Tell me if the wallpaper changed after it rebuilds")
- Never use technical jargon without immediately explaining it in plain terms

**Branch Naming Convention (STRICT)**:
- All branches for insideabush's work MUST use the prefix `blaney/`
  - Examples: `blaney/feat-party-mode`, `blaney/fix-wifi-issue`
- This prefix distinguishes insideabush's branches from lando's branches — do not deviate from it
- When continuing prior work, reuse the existing `blaney/` branch if still relevant; check `git branch -a` first

**Git Workflow (STRICT)**:
- **NEVER push or commit directly to `main`** — always use a `blaney/` branch
- **NEVER merge into any branch that does not start with `blaney/`** — this includes `main` and all branches created by lando or his Claude sessions
- insideabush's Claude sessions CAN: create new `blaney/` branches, push to those branches, merge other existing branches INTO a `blaney/` branch
- insideabush's Claude sessions CANNOT: push to `main`, push to any non-`blaney/` branch, merge a `blaney/` branch into a non-`blaney/` branch
- When insideabush confirms a feature is working and acceptable: open a PR from the `blaney/` branch to `main` via `gh pr create`
- **Never merge the PR** — lando (`landonreekstin`) merges all PRs from blaney-pc

**Safety**:
- Always use `nixos-rebuild test` before `rebuild` for significant changes, so insideabush can verify before permanently switching
- Keep changes focused and minimal

## The shutdown guard

blaney-pc updates itself unattended every Monday at 03:00 and powers off afterwards
(`customConfig.services.autoUpdate` in `hosts/blaney-pc/networking.nix`), but only if it
was left on — and anything lando pushes mid-week would otherwise wait for that. So every
shutdown is a chance to install what's new.

`customConfig.homeManager.services.shutdownGuard` (declared in
`modules/nixos/common/home-manager.nix`, implemented in
`modules/home-manager/services/shutdown-guard.nix`) installs a `shutdown-guard` command
that every shutdown path runs first. It does a bounded `git fetch origin main` (gives up
after 4s offline, falling back to the last-fetched ref) and does nothing at all unless
`HEAD..origin/main` has commits **or** (with `offerTasks`, on for blaney-pc) runbooks are
waiting in [`blaney-todo`](#runbooks-as-blaney-pc-tasks). Otherwise it shows a themed GTK3
dialog: **Cancel**, **Shut down anyway**, **Update now, then shut down** (only when there
are new commits; runs `update-shutdown` in a terminal) and **Have Claude do a task, then
shut down** (only when tasks are waiting; runs `blaney-todo --unattended` in a terminal —
see [Walk-away runs](#walk-away-runs)). Runbooks a walk-away run already finished are not
counted. The comparison is against `HEAD`, so on a `blaney/` branch that is behind main the
update button keeps appearing — `update` pulls the branch, not main.

Paths that run the guard:

| Path | How |
|---|---|
| Start menu → Shut Down | `Guarded(...)` around the Shut Down action in `modules/home-manager/themes/windows7-xfce/power-menu.nix` |
| `<Super>BackSpace` | rebound from `xfce4-session-logout` to the same flyout (`keybindings.nix`) |
| The case's power button | `XF86PowerOff` → the flyout, with `services.logind.settings.Login.HandlePowerKey = "ignore"` in `hosts/blaney-pc/system.nix` |

Restart, Log Off and Sleep are **not** guarded: they leave the machine powered on, so the
weekly timer still fires.

Two things to keep in mind when touching this:

- **It fails open on purpose.** Only an explicit "hold" status blocks a shutdown; a missing,
  crashed or display-less guard lets the shutdown through. A guard bug must never leave
  insideabush with a PC that refuses to turn off.
- **The power button is an X grab race.** `xfce4-power-manager` `XGrabKey`s `XF86PowerOff`
  on the root window unconditionally at startup, competing with xfsettingsd for the same
  grab. xfsettingsd normally wins (it starts with the session core; xfpm only later from
  the tray autostart), which is why the keybind works. `idle.nix` pins xfpm's
  `power-button-action` to 0 so that if xfpm *does* win, the button does nothing rather
  than powering off unguarded. Scripted poweroffs (`systemctl poweroff`, `rebuild-shutdown`,
  `update-shutdown`, the auto-update service itself) are deliberately never guarded —
  blocking those would break the automation the guard exists to protect.

## Lando over SSH

lando can `ssh blaney` from gaming-pc to do nix work, but only while Blaney has the homelab
VPN switched on (`autoconnect = false`). It is built so lando never needs to touch
insideabush's files (`modules/nixos/services/remote-admin.nix`):

- **A separate `lando` account**, key-only (gaming-pc's key), `AllowUsers lando`, sshd open
  only on `wg-homelab`. insideabush gets no authorized keys. `customConfig.services.ssh`
  stays off on purpose: it would put the admin keys on *his* account.
- **sudo is an allowlist**, not `wheel`: `nixos-rebuild`, `systemctl`, `journalctl`,
  `nix-collect-garbage`, with the password from `lando-password-hash` in
  `secrets/blaney-pc-admin.yaml`. This is a guardrail against casual access, not a wall, since a
  rebuild can do anything as root. The backstop is visibility: Blaney gets a desktop
  notification on every connect and disconnect (a pam_exec rule on sshd), and every sudo
  command is in the journal.
- **Work in your own clone**, `/home/lando/nixos-config` on blaney-pc, never in his. `rebuild`
  and `wt` there resolve to *his* tree (`MAIN_CONFIG`), so from the admin account rebuild
  with `sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname) --impure`. Push a branch
  (the shortcut forwards your agent); his weekly update pulls `main` again afterwards.
- **The path in:** gaming-pc routes `10.10.0.0/24` into `wg-nas`; optiplex-fw passes tcp/22
  from 10.10.0.2/10.10.0.11 to 10.10.0.5 ahead of the `<restricted_peers>` block; and his
  NM profile's `allowed-ips` include those two addresses so WireGuard accepts them.

## His own app projects

Separate from everything above: insideabush also builds his own small apps, with the `vibe`
command. Those live in `~/projects/<slug>` as git repos (local-only or on his own GitHub) he commits to `main`
directly, and a session in one of them is governed by `~/projects/CLAUDE.md`, not by this
file. See [blaney-vibe-projects.md](blaney-vibe-projects.md). The rules here still bind
anything that touches *this* repo.

One of them is his **Hyprland desktop**: the Glade, a pixel-art forest he clicks around
to open his apps, with a session built to be used by mouse alone or steered from the
keyboard (the `glade` Hyprland desktop, [theming.md](../theming.md#the-glade-theme)). It is
blaney-pc's only Hyprland desktop, so there is no live switching (Super+Shift+D) there. This machine cannot run the test VMs (no
KVM); Hyprland changes are verified nested inside KWin instead
([test-vms-and-ci.md](../test-vms-and-ci.md#testing-hyprland-without-kvm-nested-in-kwin)).

## Runbooks as blaney-pc tasks

`docs/runbooks/blaney/*.md` is the task queue lando leaves for blaney-pc. Each markdown
file is one task; its first `# ` heading is the menu entry insideabush sees.

The loop:
1. lando adds `docs/runbooks/blaney/<name>.md` on `main` and pushes
2. insideabush runs `blaney-todo`, which fetches `origin/main`, lists the runbooks by
   number, and launches `claude` on the chosen one with the blaney-pc preface prompt
   (defined in `modules/nixos/common/commands.nix` — keep it in sync with the rules above)
3. Claude does the work on a `blaney/` branch and opens a PR
4. **lando merges the PR and deletes the runbook file** — deleting it is the only thing
   that removes the task from the menu

Notes:
- Only `docs/runbooks/blaney/` feeds the menu; other runbooks under `docs/runbooks/` are
  ordinary docs and never appear. `README.md` in that folder is the authoring guide and is
  filtered out.
- This is separate from `TASKS.md`, which remains lando's own list.
- When working *on* a blaney runbook: never edit, move, or delete the runbook file itself.

### Walk-away runs

After picking a task, `blaney-todo` asks whether to work on it together or let Claude do it
on its own (`blaney-todo --unattended` skips that question; the shutdown dialog uses it).
The walk-away path asks for the sudo password once, while insideabush is still there, then
runs `blaney-todo-unattended` as root:

1. `claude -p` with `--permission-mode auto --permission-prompts none` and a walk-away
   variant of the preface prompt: no questions, Claude makes the visual calls too, verifies
   by itself, and opens the PR with "Decisions I made for Blaney" / "Needs checking in
   person" sections (as a **draft** if part of the task physically needs him). Bounded by a
   4h `timeout`, under `systemd-inhibit` so XFCE idle can't suspend mid-task.
2. Success = the repo is on a `blaney/*` branch with a PR. That writes
   `~/.local/state/blaney-todo-result` (reported by `rebuild-shutdown-notify` at the next
   login) and appends the runbook to `~/.local/state/blaney-todo-done`, which labels it
   "(done, waiting for Lando)" in the menu and drops it from the shutdown dialog's count.
3. Leftover uncommitted files are stashed (`blaney-todo:<branch>`), the repo goes back to
   `main`, and `update-shutdown` pulls, rebuilds main and powers off — so the machine boots
   into main while the PR waits, and the weekly update isn't missed.

The full transcript is in `~/.local/state/blaney-todo-unattended.log`. When writing a
runbook, assume it may run this way: say what "done" looks like in terms Claude can check
itself, and leave any must-be-there-in-person step clearly separate.

