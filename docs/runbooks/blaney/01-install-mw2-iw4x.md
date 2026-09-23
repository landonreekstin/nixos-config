# Install Call of Duty: Modern Warfare 2 and IW4x

**What's wrong / what's wanted:** Blaney wants to play Modern Warfare 2 (2009) multiplayer
with lando. IW4x is the community client that makes that possible — the original
matchmaking servers have been dead for years. It is a *mod*, so it needs a full MW2
installation underneath it.

This is already working on gaming-pc. The module and both commands exist; this task is
enabling them here and getting the game files onto this machine.

**Prerequisite — check this first and stop if it fails.** This needs
`customConfig.programs.iw4x` to exist:

```bash
test -f modules/nixos/programs/iw4x.nix && echo OK || echo "NOT MERGED YET"
```

If it prints `NOT MERGED YET`, the module has not reached `main`. Tell Blaney the task
isn't ready, don't try to write it yourself, and stop.

**Where:**
- `hosts/blaney-pc/apps.nix` — the `customConfig.programs` block (partydeck lives there)
- `modules/nixos/programs/iw4x.nix` — read it, don't change it

## Background you need

- **The game files are on a USB drive**, not the NAS. blaney-pc genuinely cannot reach the
  NAS over SMB — `pf` on the firewall blocks it for restricted VPN peers. Do not try to
  mount the NAS, and do not enable `nasClient`; both will fail. (Full detail in
  `docs/runbooks/mw2-iw4x-source.md`. A `public` share that would fix this is designed but
  not built: `docs/runbooks/nas-public-share.md`.)
- **The drive may hold either form.** Check which before planning:
  - a prepared `mw2/` directory (~15 GB) — already installed and IW4x-synced. **Prefer
    this.** Copy it and skip `mw2-install` entirely.
  - `sr-mw2a.iso` + `sr-mw2b.iso` (~12 GB) — run `mw2-install /path/to/isos`.

## Do this

1. **Check free space before anything else**, and stop if it's short. blaney-pc has one
   filesystem, so this all lands on `/`:
   ```bash
   df -h /
   ```
   - copying a prepared directory: **~16 GB**
   - installing from ISOs: **~37 GB peak** (12 GB unpacked ISOs + 12 GB extracted payload
     + 13 GB game), settling to ~15 GB
   If there isn't room, say so plainly and stop — do not start and fill the disk.

2. **Find the monitor's native resolution.** MW2 is capped at 1920x1080 internally, and
   the module runs it inside gamescope to upscale to the real panel. On gaming-pc this
   fixed a genuine bug, so get the number right rather than guessing:
   ```bash
   wlr-randr 2>/dev/null || kscreen-doctor -o || xrandr --listmonitors
   ```
   If it is 1920x1080 or smaller, leave `outputWidth`/`outputHeight` unset — the defaults
   are correct and gamescope will use the native mode.

3. **Branch** — `blaney/install-mw2-iw4x`.

4. **Enable the module** in `hosts/blaney-pc/apps.nix`, inside the existing
   `customConfig.programs` block:
   ```nix
   iw4x = {
     enable = true;
     # Add gamescope.outputWidth / outputHeight only if the panel is above 1080p.
   };
   ```
   Leave `installDir` at its default (`~/Games/mw2`) and set no `mediaDir` — the media
   comes from a USB path passed on the command line, which varies.

5. **`sudo chown -R insideabush:users /home/insideabush/nixos-config`, then `rebuild`.**

6. **Get the game in place.**
   - Prepared directory: `mkdir -p ~/Games && cp -a /run/media/…/mw2 ~/Games/`
   - ISOs: `mw2-install "/run/media/…/<iso dir>"` — takes a while, most of it reading the
     USB drive. It needs no display and no clicking.

7. **Launch it:** `iw4x`. The first run downloads ~750 MB of IW4x files.

   **Expect it to re-download ~730 MB on every launch.** That is an upstream launcher bug
   seen on gaming-pc too, not something you broke here. Don't go chasing it.

8. **Verify properly** — reaching the menu is not enough, the whole point is multiplayer:
   - the game opens fullscreen at the monitor's native resolution
   - the IW4x entry in the applications menu launches it
   - **Blaney joins a server and plays a round**

9. **Ask Blaney** whether he wants the IW4x icon pinned to his taskbar. If yes, add it to
   `customConfig.homeManager.themes.xfcePanel.pinnedApps` (or `themes.pinnedApps` for KDE)
   the same way Lutris and Steam are done in `hosts/blaney-pc/home.nix`.

10. **Open a PR** against `main` and stop. Do not merge it — lando does that.

## Traps

- **Don't run `mw2-install` or `iw4x` with `sudo`.** Both refuse, on purpose: everything
  they write has to be owned by Blaney, and as root the launcher later fails trying to
  write into a root-owned game directory, with an error pointing nowhere near the cause.
- **Quote the USB path.** The media directory name contains spaces and literal `[` `]`.
- **Don't set the resolution by editing `players/iw4x_config.cfg`.** MW2's `r_mode` is a
  fixed list ending at 1080p and an unrecognised value silently falls back to 640x480.
  gamescope is what fills a bigger screen.
- If the game looks mostly black with the picture in one corner, that is the multi-monitor
  XWayland bug — gamescope should prevent it, so check gamescope is actually running
  before changing anything in the game.
