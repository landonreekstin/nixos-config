# Send the glade banner notes to Lando

**What's wrong / what's wanted:** Blaney's latest glade changes are already pushed: squid
only on the left trees, glowing banners (paths and apps/files in different colours), and
clicks going to the banner instead of the squid. They're in `cblaney00/glade` at f28ba1b,
and `pkgs/glade` on `blaney/feat-tree-squids` pins that commit. The one thing missing is
the write-up in PR #218's description. GitHub's API timed out at the end of that session
(2026-10-26), so `gh pr edit` never ran. Lando reviews from the PR text, so it needs
adding.

**Where:**
- PR #218 (`blaney/feat-tree-squids`) in `landonreekstin/nixos-config`
- The section to add is reproduced below.

**Do this:**
1. Run `sudo -u insideabush -H gh pr view 218 --repo landonreekstin/nixos-config --json state,body`.
   If the body already has a "Follow-up: left trees, glowing banners" section, skip to step 4.
2. If the PR is still **open**, append the section below to its body, just above the
   closing `🤖 Generated with …` line. Write it to a temp file and use
   `gh pr edit 218 --body-file` (as `insideabush`). Leave the rest of the body unchanged.
3. If it's already **merged or closed**, post the section as a comment instead
   (`gh pr comment 218 --body-file …`).
4. Delete this runbook on a `blaney/` branch and open a PR for that. Don't commit to
   `main` (see `docs/hosts/blaney-pc.md`).

Don't rebuild anything or change any glade code. This task is only about the PR text.

**Done when:** PR #218 carries the section below, either in its body or as a comment.

## The section to add

## Follow-up: left trees, glowing banners (`cblaney00/glade` f28ba1b)
Blaney asked for this after seeing the squids live. `pkgs/glade` is now bumped 937ab11 → f28ba1b.
- Tree squids only go on the five left trees (x=28…306) now, with one squid per tree on its first-filled spot. The other items are just their banner and fade in a squid while dragged. The blossom tree, x=676 and the right-hand trunks no longer hold any. The glade's three sky squids are removed.
- The name boards are drawn as translucent glowing "spirit-cloth" banners (gradient fill, frayed wisps) instead of wood. `MIST` tints them: mint for `go` paths, violet for apps and files. The minimap is still the wooden style.
- For a tree squid's spot, only the banner is a hit target (`Signs.prepare`), so clicks and drags land on the banner, not the squid.
- Checked: ruff is clean on main/squids/scenes. `--shots` renders at 9.4 ms/frame. Rebuilt and running live on blaney-pc, and screenshotted.

