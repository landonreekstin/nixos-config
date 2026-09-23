# Install Call of Duty: Modern Warfare 2 and IW4x

**What's wrong / what's wanted:** Blaney wants to play Modern Warfare 2 (2009) multiplayer
with lando. IW4x is the community client that makes that possible — the original
matchmaking servers have been dead for years. It is a *mod*, so it needs a full MW2
installation underneath it.

This is already working on gaming-pc. The module and both commands exist; this task is
enabling them here and getting the game files onto this machine.

**Prerequisites — check both first and stop if either fails.**

1. The module must exist:

```bash
test -f modules/nixos/programs/iw4x.nix && echo OK || echo "NOT MERGED YET"
```

If it prints `NOT MERGED YET`, the module has not reached `main`. Tell Blaney the task
isn't ready, don't try to write it yourself, and stop.

2. The NAS file drop must be up — this is where the game comes from:

```bash
curl -sI http://192.168.1.76/public/ | head -1     # expect 200
```

Blaney must have the homelab VPN connected in the KDE network applet for this to
answer at all. If it 404s or the vhost is missing, the drop has not been built yet
(`docs/runbooks/nas-public-share.md`) — tell Blaney and stop.

**Where:**
- `hosts/blaney-pc/apps.nix` — the `customConfig.programs` block (partydeck lives there)
- `modules/nixos/programs/iw4x.nix` — read it, don't change it

## Background you need

- **The game comes from the NAS over HTTP**, at `http://192.168.1.76/public/`, with the
  VPN connected. Blaney is remote, so this crosses the internet -- expect it to take a
  while and use a resumable download.
- **Do NOT try to mount the NAS over SMB and do NOT enable `nasClient`.** Both will fail:
  `pf` on the firewall blocks 445/139 for restricted VPN peers, and blaney-pc has no sops
  identity to hold the Samba credentials. HTTP on port 80 is the one path that is open.
  (Full detail in `docs/runbooks/nas-public-share.md`.)
- **Prefer `mw2.tar`** if the drop has it (~15 GB, already installed and IW4x-synced) --
  untar it and skip `mw2-install` entirely. The two ISOs are the fallback and need far
  more free space.

## Do this

1. **Check free space before anything else**, and stop if it's short. blaney-pc has one
   filesystem, so this all lands on `/`:
   ```bash
   df -h /
   ```
   - downloading and untarring `mw2.tar`: **~31 GB peak** (15 GB tar + 15 GB extracted),
     settling to ~15 GB once the tar is deleted
   - installing from ISOs: **~37 GB peak** (12 GB downloaded ISOs + 12 GB unpacked + 12 GB
     extracted payload + 13 GB game), settling to ~15 GB
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
   is downloaded to ~/Games directly, and the ISO fallback takes its path on the command
   line.

5. **`sudo chown -R insideabush:users /home/insideabush/nixos-config`, then `rebuild`.**

6. **Download the game from the NAS.** Use `curl -C -` so a dropped connection resumes
   instead of starting 15 GB over:
   ```bash
   mkdir -p ~/Games && cd ~/Games
   curl -C - -O http://192.168.1.76/public/mw2.tar
   tar -xf mw2.tar && rm mw2.tar
   ```
   If the drop only has the ISOs instead, download both the same way and then run
   `mw2-install "<dir holding them>"` -- it needs no display and no clicking, but check
   the space numbers in step 1 again first.

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
- **Quote any media path.** If you fall back to the ISOs, the directory name they came
  from contains spaces and literal `[` `]`.
- **Don't set the resolution by editing `players/iw4x_config.cfg`.** MW2's `r_mode` is a
  fixed list ending at 1080p and an unrecognised value silently falls back to 640x480.
  gamescope is what fills a bigger screen.
- If the game looks mostly black with the picture in one corner, that is the multi-monitor
  XWayland bug — gamescope should prevent it, so check gamescope is actually running
  before changing anything in the game.
