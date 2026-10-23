# Put the latest Glade on GitHub

**What's wrong / what's wanted:** The Glade's code is published at
`github:cblaney00/glade`, but nixos-config still builds it from a copy pasted into
`pkgs/glade/src`. The repo-wide rule (`CLAUDE.md` → Companion Repositories) is that an app
like this lives only in its own repo and is pinned by `fetchFromGitHub` — never a vendored
`src/`. The switch couldn't be done from lando's side: the newest Glade change ("apex is an
amorphous blob…", commit 89b73e6 in PR #203) is in `pkgs/glade/src` but was **never pushed**
to `cblaney00/glade`, whose `main` is still `e7d5c2f`, and only Blaney's account can push there.

**Where:**
- `~/projects/hud` on blaney-pc — the project; its `glade/*.py` are the program
- `pkgs/glade/default.nix` and `pkgs/glade/src/` in nixos-config
- `docs/companion-repos.md` — "Still vendored" list; add a `## glade` section

**Do this:**
1. In `~/projects/hud`: `git status` and `git log --oneline -5`; `git remote -v` should point
   at `cblaney00/glade`. Commit anything uncommitted under `glade/` (his project, his `main`,
   per `docs/hosts/blaney-vibe-projects.md`), then `git push origin main`.
2. Confirm the published code is what blaney-pc runs today: every file in
   `~/projects/hud/glade/*.py` at the pushed commit must be byte-identical to
   `pkgs/glade/src/*.py` on `origin/main` of nixos-config (`diff -r`). If they differ, stop
   and say which is newer — do not guess.
3. On a `blaney/` branch from `origin/main`, change `pkgs/glade/default.nix` to
   ```nix
   src = fetchFromGitHub {
     owner = "cblaney00";
     repo = "glade";
     rev = "<full sha you just pushed>";
     hash = lib.fakeHash;   # build once, copy the real hash from the mismatch error
   };
   sourceRoot = "source/glade";
   ```
   (add `fetchFromGitHub` to the function arguments, set `version` to the commit date, and
   rewrite the header comment: the source is no longer vendored). Delete `pkgs/glade/src/`.
   Use the `lib.fakeHash` build to get the hash — `nix-prefetch-url` was refused by the
   auto-mode classifier on this machine before.
4. Prove nothing changed: the new build's `share/glade/*.py` must be identical to the old
   vendored ones (`diff -r` the two store paths).
5. `docs/companion-repos.md`: remove glade from "Still vendored", add a `## glade` section
   (source, package path, how to bump — like the others).
6. Rebuild, check the Glade is running on both monitors and a board click still opens an
   app, then open the PR.

**Done when:** `pkgs/glade/src` is gone, `pkgs/glade` fetches `cblaney00/glade` at the pushed
rev, and the Glade on screen behaves exactly as before.

**Notes:** Nothing for Blaney to decide here; it's purely technical. If the push needs a
GitHub login that isn't set up, stop and open a draft PR saying so rather than inventing
credentials.
