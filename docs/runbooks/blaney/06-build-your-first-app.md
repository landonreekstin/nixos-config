# Build your first app of your own

**What's wanted:** Blaney now has a `vibe` command for building his own small apps. This
task is the first real run of it: get it onto his machine, confirm the pieces are actually
there, and then hand him over to it.

**Background:** `vibe` (PR #164) is his front door to apps *he* builds, as opposed to
changes to this config. Each app is a local-only git repo in `~/projects/<slug>` that he
commits to `main` in directly; this repo's `blaney/`-branch-and-PR rules do not apply
inside those folders. The full design is in
[docs/hosts/blaney-vibe-projects.md](../../hosts/blaney-vibe-projects.md) — read it before
starting, especially the ownership section.

It has been exercised end to end in `vm-blaney`, so the command, the menu, the repo
scaffolding and both dev shells are known good. The one thing a VM could not test is a
real Claude session, which is what this task is for.

**⚠️ You cannot run `vibe` yourself.** It ends in `exec sudo claude`, and you are already
inside a Claude session — it cannot nest. Handing Blaney the word `vibe` to type is the
one and only command you should hand him in this task, and it is correct to do so: it is
the entry point to a *different* session, not a chore you are offloading.

**Do this:**

1. Make sure he is on the latest `main` and rebuilt, since `vibe` only exists after that:
   ```bash
   cd ~/nixos-config && git status --short && git rev-parse --abbrev-ref HEAD
   ```
   If he is on a `blaney/` or `update/` branch, use `smart-rebuild`'s logic — preserve any
   work in progress first, tell him in one sentence where it went, then get to `main`,
   `update`, and `rebuild`. Never discard a branch or stash without asking him.

2. Confirm the pieces landed. All five of these should be true; if any is not, diagnose and
   fix it on a `blaney/` branch, and open a PR rather than working around it:
   ```bash
   command -v vibe
   ls -l ~/projects/CLAUDE.md ~/projects/README.md   # both symlinks into /nix/store
   nix develop ~/nixos-config#vibe-python --command python -c 'import pygame; print("ok")'
   nix develop ~/nixos-config#vibe-web --command node --version
   blaney-help | grep -A2 'BUILD YOUR OWN'
   ```
   Note the two `nix develop` lines must **not** be prefixed with `sudo` — a nested sudo
   resets `SUDO_UID` and nix then refuses to read his config repo
   (`libgit2 error code = 7`). This is explained in the doc.

3. Ask him what he'd like his first app to be, in plain English, and give him two or three
   concrete suggestions sized for a first go — something like a countdown timer, a dice
   roller, a soundboard, or a little snake game. **Do not** ask him anything technical and
   do not mention languages; `vibe`'s own session picks that.

4. Tell him to close this session and type `vibe`, then pick "start a brand new app" and
   give it the name you both settled on. One sentence, no jargon.

**Done when:** he has run `vibe`, created an app, and the session inside it has built
something he can actually open and use. He will be able to get back into it afterwards with
`vibe` → the app → "pick up where you left off".

**Notes:**

- Do **not** create his project directory or app files from this session. The whole point is
  that `vibe` sets the project up and the session it launches does the building, with the
  right rules loaded (`~/projects/CLAUDE.md`, which this session does not read).
- If something about `vibe` itself turns out to be wrong, fix it here on a `blaney/` branch
  and open a PR — that is a config change and follows the normal rules.
- Leave this runbook file alone; lando deletes it when he merges.
