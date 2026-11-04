# Tidy up Blaney's task menu

**Run on:** any of lando's machines.

**What's wanted:** Blaney's `blaney-todo` menu still lists tasks that look finished, and only
lando removes runbooks. Blaney asked for this on 2026-11-03.

**Do this:**

1. Check each of these against the current repo, then ask lando before removing any:
   - `docs/runbooks/blaney/01-install-mw2-iw4x.md`: Blaney confirmed the two of them have
     played MW2 together.
   - `docs/runbooks/blaney/06-build-your-first-app.md`: Blaney now builds apps with `vibe`
     regularly (Glade, R62D, VibeNote).
   - `docs/runbooks/blaney/10-publish-glade-update.md`: Glade now comes from
     `cblaney00/glade` rather than a `src/` tree in this repo.
2. Delete the confirmed ones, and tick the `vibe` item in `TASKS.md` if 06 goes.
3. Delete this runbook in the same change.

**Done when:** those tasks no longer appear in `git ls-tree --name-only origin/main docs/runbooks/blaney/`,
and neither does this one in `docs/runbooks/lando/`.

**Not part of this:** `docs/runbooks/blaney/13-fix-vpn-handshake.md` may end up pointing at
lando's router, but Blaney's side of it comes first. Leave it alone.
