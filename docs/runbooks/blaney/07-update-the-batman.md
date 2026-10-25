# Update The Batman (co-op fixes)

**What's wanted:** blaney-pc gets the new version of *The Batman*. It fixes two co-op bugs from
the first online game:
- the game froze for both players when Lando searched at a locked door;
- Batman couldn't open some doors he stood at.

Lando's gaming-pc gets the same version. Online play needs both machines on the same version of
`pkgs/batman`. A machine on the old one is refused with "the host refused: a different
build...".

**Do this:**
1. **Get the latest config.** Run `update` (it pulls `main` and rebuilds). If it fails, follow
   the usual rebuild-failure path; don't hand-edit around it.
2. **Check the version.** `grep -o 'rev = "[0-9a-f]*"' ~/nixos-config/pkgs/batman/default.nix`
   should print `rev = "d8311639dda723265325b23320efd48b1a8865f1"`, or a newer rev if this
   runbook is older than the config.
3. **Tell Blaney** it's ready. The next time Lando hosts, "The Batman: Join Online Game" works as
   before. Nothing else changes: same start-menu entries, same controls, same save.

**Done when:** `update` finished and the rev matches.

**If it doesn't work:**
- Every failure shows its reason on screen or in a dialog. The full log is
  `~/.local/share/batman/last.log`.
- **"the host refused: a different build..."**: one of the two machines is on the old version.
  Check the rev here (step 2). If it matches, gaming-pc hasn't been updated yet: tell Lando.
- **"no answer from 192.168.1.76 (is the VPN on?)"** with `homelab-vpn` on: the path to Lando's
  game is broken (`docs/networking.md`, "The Batman netplay"). Blaney can't fix that: tell Lando.
- Don't change `pkgs/batman` or the module from blaney-pc. If something in them is wrong, write
  down what you saw, tell Blaney to pass it on to Lando, and stop.

**Notes:** no PR is needed.
