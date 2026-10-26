# Finish the tree squids, F-117 and the Apps menu fix

**What's wanted (Blaney's words and choices, 2026-10-25):**
1. **F-117** (his vibe app, `~/projects/breifing-room`, launched by its `run.sh`) should
   show up in **app search** (the Apps menu / rofi drun).
2. **Tree squids become his desktop icons.** He first asked for the squid in the tree
   hollow (it opened "Glade Pictures") to open F-117 instead, and for the Glade Pictures
   squid to go, then made it general:
   - **every app AND every item in his Desktop folder** is a little squid on the Glade's
     tree trunks, with its name on a board (full name on hover);
   - they **resize automatically** to the space left (smaller and closer together when
     crowded);
   - they **climb** (animated) to the next sensible spot to **make room** when one is added
     or removed: up/down their own trunk hand over hand; to another tree they swim across;
   - he can **drag** one to a spot (it stays there, swapping with whoever was there);
   - they are **ranked by how often he clicks them** (most-clicked get the best spots).
   He said yes to the apps' old wooden boards (lantern, boat, cave...) going away.
3. **Bug:** the Apps menu (top bar "✿ Apps", rofi) doesn't close when he clicks outside it.
   He is stuck until he picks an app.

His standing Glade preferences are in Claude's memory (`glade-desktop-preferences`),
including that **nothing may react instantly to a click** (use `life.swell`).

## Already done (on branch `blaney/feat-tree-squids`, stacked on `blaney/feat-glade-snap`)

- **Apps menu fix (item 3), written but not yet rebuilt.** Cause: Wayland rofi has no
  click-to-exit, takes the keyboard exclusively, and Hyprland swallows clicks beside it on
  its monitor. The fix:
  - `glade/rofi.nix`: the window is fullscreen and see-through, and the card is the `mainbox`
    centred with `calc()` margins;
  - `glade/desktop.nix`: `kb-cancel` gains `MousePrimary`;
  - `glade/dock.py`: a new `glade-dock apps` mode puts a clear layer-shell sheet on every
    monitor, so clicks on the *other* screen close it too. The waybar button runs it.

  Both halves were tested live with `wlrctl` and a scratch theme (a click beside the card
  cancels and a click on an entry selects; a click on the other monitor closes it). Still
  to do: `rebuild --take` from this worktree, then check that the real button opens and
  closes the menu and that clicking an app still launches it.
- **Squids, half written,** in the Glade project `~/projects/hud` (its main, commit
  `27b7e69` "Work in progress…"; **not pushed**, so don't publish it until it's finished):
  - `glade/squids.py`: `Colony` (Desktop watcher thread, ranking by clicks from
    `~/.local/state/glade/squids.json`, pins, `LEVELS` for resizing, slots on trunks,
    `grab`/`drag`/`drop`) and `TreeSquid` (clinging drawing, climb/swim routes);
  - `glade/scenes.py`: trunk leans captured, the `Colony` added to the Glade on 7 trunks,
    `HollowSquid` removed, and every `Spot("app", …)` removed from all places.

## Still to do

1. **Hook the squids into `main.py`:** drop `"pictures"` from `APPS`/`ICON_PAINTERS`; drop
   the `pet.duck` lines in `Glade.activate` and call `sp.squid.colony.clicked(sp.squid, t)`
   when a spot has `.squid`. **Dragging:** on press over a squid spot `colony.grab`, follow
   the pointer every frame with `colony.drag(view.mouse())`, then on release either `drop`
   (if it moved more than ~6 canvas px) or treat it as a click. That needs button-release
   handling in `main.py` (`MOUSEBUTTONUP`) and in `wayland.py` (`BUTTON_RELEASE_MASK` plus a
   `button-release-event` handler).
2. **`orchard.py`:** `Orchard.refresh` overwrites `scene.spots` with its own `base`, which
   would wipe the squid's spots. Make it replace only its own spots, the way
   `Colony.arrange` does with `self.mine`.
3. `apex.py` handles `HollowSquid` by class name. Decide whether the apex eats tree squid,
   and make sure nothing breaks either way. Run `ruff check glade/` (an unused import is
   left over in scenes.py).
4. **Look at it:** `python glade/main.py --shots DIR` and judge the art. Check that the
   boards on neighbouring trunks don't collide at 28 items (his Desktop holds ~20 plus 7
   apps), and test with a fake Desktop of 45 (set `HOME` to a scratch dir) to check the
   smaller levels. Keep each frame around 10 ms.
5. **F-117 in search and on the Desktop:** a home-manager `xdg.desktopEntries."f-117"`
   (name "F-117", Exec `/home/insideabush/projects/breifing-room/run.sh`, an icon), plus the
   same entry as `~/Desktop/F-117.desktop` so it gets a squid. It runs from his project
   folder on purpose, because he is still building it; real packaging comes later
   (`docs/hosts/blaney-vibe-projects.md`, "Packaging a finished app").
6. Commit the Glade project, `git push origin main` as insideabush (`gh` is logged in as
   cblaney00), and bump `pkgs/glade` (rev, hash, version; see
   `docs/companion-repos.md#glade`). Note: its local main was already one commit
   (`9f0cd63`, minimap) ahead of the pinned `a23e29b`.
7. `rebuild --take`. Then have Blaney check the Apps menu, F-117 in search, and the squids
   (click, drag, add a file to Desktop and watch them make room). Then open the PR.

**Done when:** F-117 appears in app search and as a squid; every app and Desktop item is
a tree squid that is ranked, resizes, climbs/swims to make room, and can be dragged; a
click outside the Apps menu closes it.
