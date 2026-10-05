# Open the PR for the monitor arrangement that was already set up

**What's wrong / what's wanted:** Blaney's monitor positions were configured in an earlier
session on this machine and they work, but **nothing was ever pushed**. `origin/main` still
has no `customConfig.desktop.monitors` for this host — `hosts/blaney-pc/home.nix` even
carries a comment saying "he has no desktop.monitors yet". So the arrangement is living in
uncommitted/unpushed local state and will be lost the next time something resets the tree.

This task is **recovery and paperwork**, not new work. Find that configuration, get it onto
a `blaney/` branch, confirm it still behaves, and open the PR.

**Where:**
- `hosts/blaney-pc/desktop.nix` — owns `customConfig.desktop`, so `desktop.monitors` belongs
  here and nowhere else (see the Host File Layout table in `CLAUDE.md`)
- `hosts/blaney-pc/home.nix` — has a stale comment about there being no monitors yet
- `modules/home-manager/xfce/monitors.nix` — read it, don't change it; it is the resolver
- `modules/nixos/desktop/options.nix` — the `desktop.monitors` option schema (incl. `edid`)

## Step 1 — find the work. Check all four places before concluding it is gone.

```bash
cd ~/nixos-config
git status                      # uncommitted edits in the working tree?
git stash list                  # branch-switch saves stashes tagged "branch-switch:<branch>"
git branch -vv                  # a local blaney/… branch that was committed but never pushed
git log --oneline --all -20     # anything touching desktop.nix
git log -p --all -- hosts/blaney-pc/desktop.nix | head -100
```

`branch-switch` stashes local changes with the message `branch-switch:<source-branch>`, so a
`git stash list` hit is the single most likely place this is hiding. Restore it with
`git stash apply <ref>` (apply, not pop — keep the stash until the PR is open).

**If you genuinely cannot find it anywhere**, do not guess at numbers. Rebuild the config
from the live session instead, which is authoritative:

```bash
xrandr --listmonitors
xrandr --verbose | grep -A1 " connected"     # connector names + current mode/position
xrandr --verbose | grep -iE "EDID|^[A-Z]+-[0-9]| [0-9]+x[0-9]+"
```

Then ask Blaney to confirm which screen is on the left and which is his main one — that part
is his call, not yours.

## Step 2 — write it into `hosts/blaney-pc/desktop.nix`

Add a `monitors` list inside the existing `customConfig.desktop` block. Shape:

```nix
monitors = [
  {
    name = "main";                      # "main" marks the primary — exactly one monitor
    identifier = "DP-1";                # Wayland/Hyprland selector
    edid = "<make/model substring>";    # X11/XFCE selector — see below, do not skip
    resolution = "1920x1080";
    position = "0x0";
  }
  {
    name = "secondary";
    identifier = "HDMI-0";
    edid = "<make/model substring>";
    resolution = "1600x900";
    position = "1920x0";
  }
];
```

Three things that are easy to get wrong here:

- **Set `edid` on every monitor.** X11 (NVIDIA) and Wayland report *different* connector
  names for the same physical port, and X11 names reorder between reboots. The XFCE resolver
  matches on the `edid` substring when present and only falls back to `identifier` when it is
  null. Without `edid` the layout will work until the next reboot shuffles the names. Read the
  EDID the resolver reads — from inside the X session, via `xrandr --verbose` (NVIDIA leaves
  `/sys/class/drm/*/edid` empty, so sysfs is useless here).
- **`name = "main"` picks the primary**, which decides which panel gets the system tray and
  volume applet. If no monitor is named `main`, the first enabled one wins.
- **Don't set `scale`.** It is deliberately not translated to X11 — per-output `xrandr --scale`
  is blurry and shifts neighbour coordinates. Both of Blaney's panels are 1:1 anyway.

## Step 3 — know what else this changes, and check it

Adding `desktop.monitors` is not inert on this host. It changes three things at once:

- **The Win7 taskbar is cloned to every enabled monitor** (`panel.nix` generates one panel
  per monitor; with no monitors configured it generates exactly one). Blaney will get a second
  taskbar on his second screen. The system tray + volume applet stay on the primary only —
  that is correct, not a bug, because status-notifier icons can register to one host.
- **Hyprland** reads the same list, so his Hyprland session gets the arrangement too.
- **Wallpaper**: portrait monitors get a vertical image. Both of Blaney's are landscape, so
  this should be a no-op — but confirm it, don't assume.

Also fix the now-wrong comment in `hosts/blaney-pc/home.nix` (around the `xfceWallpaper`
option) that says he has no `desktop.monitors` yet.

## Do this

1. Recover the config per step 1.
2. **Branch** — `blaney/xfce-monitor-positions`.
3. Write it into `hosts/blaney-pc/desktop.nix` per step 2; fix the stale `home.nix` comment.
4. `sudo chown -R insideabush:users /home/insideabush/nixos-config`
5. `rebuild`
6. **Log out and back into the Xfce Session** (pick it at the Ly login screen). The layout is
   applied by an XFCE autostart entry at login, so a rebuild alone proves nothing — the
   positions you are looking at may just be the old live state.
7. Verify, and have Blaney confirm each one:
   - both screens are in the right left/right order, with no overlap or gap
   - the mouse crosses between them where the physical bezels are
   - each screen has its own Win7 taskbar; tray + volume are on the main one
   - `Ctrl+Super+1` / `Ctrl+Super+2` turn a display off and back on, and the *other*
     monitor does not move when they do
   - his KDE and Hyprland sessions still look right
8. **Open a PR** against `main` and stop. Do not merge — lando does that.
9. Drop the stash only after the PR exists (`git stash drop <ref>`).

**Done when:** the arrangement that was already working is on `origin` in a `blaney/` branch
with an open PR, and it survives a logout/login.

## Traps

- **Do not run `xfce4-display-settings` (Displays GUI) to "save" the layout.** It writes its
  own `displays.xml`, resets the declarative positions, and is known to move monitors around
  on this setup. The declarative resolver is the only thing that should own positions.
- `desktop.monitors` goes in `desktop.nix` only. Putting it in `home.nix` or `hardware.nix`
  violates the one-owner-per-attribute rule and will collide later.
- Don't commit before step 7. "It evaluates" and "it rebuilt" are not verification on this
  repo — the monitor positions have to be seen to be right.
