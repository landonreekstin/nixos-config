# Fix the Windows 7 look — the taskbar has no glass effect

**What's wrong / what's wanted:** Watching Blaney share his screen, his XFCE taskbar is flat
and opaque — no Aero glass. The Start menu looks unthemed too. Real Windows 7 has a
translucent, slightly blurred taskbar and a translucent Start menu, and that is the whole point
of this theme. Audit the Windows 7 XFCE theme end to end and fix what is not working.

**Where:** `modules/home-manager/themes/windows7-xfce/` (whole directory) and
`modules/nixos/themes/windows7-xfce/windows7-xfce-gtk.nix` (the GTKAero package).

## Confirmed defects — these were verified by reading the theme and the package, start here

### 1. The theme's entire XFCE stylesheet is dead code

`pkgs.windows7-xfce-gtk` is upstream GTKAero. Its `gtk-3.0/` directory contains **`xfce.css`**,
which is where all the panel styling lives — including the glass taskbar:

```css
.xfce4-panel {
    box-shadow: none;
    border: 1px solid @border_dark;
    border-image: url("../buttons/taskbord.png");
    border-image-slice: 1 1 1 1;
    background: url("../assets/tasktex2.png") }
```

**`gtk-3.0/gtk.css` contains no `@import` statements at all**, so `xfce.css` is never loaded —
not by us, and not upstream either (verified against the pinned rev `9ab9903`). The panel
therefore falls back to generic GTK styling, which is exactly the flat opaque bar Blaney has.

And the two URLs in that rule are both broken in the upstream tree:

| URL in `xfce.css` | Reality in the repo |
|---|---|
| `../assets/tasktex2.png` | the file is at `gtk-3.0/thunar-assets/tasktex2.png` |
| `../buttons/taskbord.png` | **does not exist anywhere in GTKAero** |

So do **not** just add an `@import url("xfce.css")` and call it done — the import will load and
the two images will silently fail to resolve. Either rewrite the URLs in the package's
`installPhase` (the same place the `thunar.css` import is already stripped and a CSS snippet is
already appended, so there is clear precedent) or write our own panel CSS and skip upstream's.

Whichever you pick, `xfce.css` has ~400 lines of panel/tasklist/tray/xfdesktop rules beyond the
glass. Pull in what helps and leave out what breaks; judge it by looking at the result.

### 2. Nothing ever enables compositing, so translucency is undefined

`xfconf.nix`'s `xfwm4Xml` sets theme, button layout, snapping and workspaces — but **never
`/general/use_compositing`**. Without the xfwm4 compositor running, no amount of CSS or alpha
gives a translucent panel; it is a hard prerequisite. The theme should assert it explicitly:

```xml
<property name="use_compositing" type="bool" value="true"/>
```

Related, and do not break it: `gaming-compositor.nix` deliberately turns compositing **off**
while a fullscreen game is focused (it fixes real stutter on mixed-refresh multi-monitor) and
back on afterwards — its own comment calls that "restoring Aero glass", which is the intent
that was never actually delivered. Setting the xfconf default to `true` is compatible with the
watcher; it just gives it a known-good baseline. Confirm after your change that launching a
fullscreen game still drops compositing and that quitting restores the glass.

### 3. The panel never asks for any transparency

`panel.nix` emits each `panel-N` block with `position`, `length`, `position-locked`,
`icon-size` and `size` — and **no background properties at all**. `xfce4-panel` needs to be
told:

- `background-style` — `0` = use the GTK theme, `1` = solid colour from `background-rgba`,
  `2` = image from `background-image`
- `background-rgba` — a 4-element double array (r, g, b, a), where `a < 1.0` is what actually
  makes it see-through
- optionally `enter-opacity` / `leave-opacity` (uint, 0–100) for whole-window opacity

Style `0` defers to the CSS from defect 1; style `1` with a dark blue-grey at ~0.75 alpha gives
the Win7 glass tint directly and does not depend on upstream's assets. **Try both and show
Blaney.** Note the texture `tasktex2.png` is 1-bit alpha (effectively opaque), so the
see-through part has to come from the panel's own alpha either way.

Whatever you add must go in the generated XML for **every** panel, since this host gets one
panel per monitor.

### 4. The Start menu is pinned fully opaque

`panel.nix`'s `whiskerRcFor` sets `menu-opacity=100`. That is the Start menu explicitly told to
be solid. Win7's is translucent — try ~85–92 and let Blaney pick.

While you are in there, audit the rest of the Start menu against Windows 7, since Blaney
reported it looking unthemed: the orb button icon (`button-icon=${orb}`), item/category icon
sizes, the search box position, and whether the menu picks up the Win7 GTK theme at all or is
falling back to the default GTK look. A Start menu that is not themed at all is a different
bug from one that is merely opaque — work out which it is before changing numbers.

### 5. Window titlebars are not glass, and that is probably fine

For completeness, so you do not chase it: the `xfwm4` decoration PNGs in GTKAero are fully
opaque (measured mean alpha = 1.0), so titlebars are baked-in gradient artwork rather than real
translucency, and `themerc` is still labelled "Windows XP Embedded" upstream. That gives a
Win7-Basic look, not Aero glass. **Leave it alone unless Blaney says the titlebars bother him**
— making those genuinely translucent means authoring new assets, which is a separate job.

## Also audit, since this is a full pass

- **Icons**: do the taskbar pins, Start menu entries and window titlebars all show Aero icons,
  or are some falling back to stock upstream icons? The `alias_icon` calls in
  `windows7-xfce-gtk.nix` cover a known list; anything newly pinned on this host may be missing
  one. Note `alias_icon` **cannot** retheme a `.desktop` that hardcodes an absolute `Icon=`
  store path — if you hit one of those, the `.desktop` has to be overridden instead.
- **Tray applets**: all four of Blaney's (`network`, `bluetooth`, `power`, `clipboard`) present,
  correctly sized, and not duplicated.
- **Fonts**: Segoe UI actually resolving, not silently falling back.
- **Cursor**: `aero-drop`.
- **GTK apps** (Thunar, Mousepad, galculator, xreader, xpad): Win7 widgets, no obviously broken
  geometry.

## Do this

1. **Branch** — `blaney/fix-win7-aero-glass`.
2. Before changing anything, capture the current state so you can prove the change:
   `xfce4-screenshooter -f -s ~/before.png`. Also record the live values you are about to
   change, so you know what was actually in effect versus what the files say:
   ```bash
   xfconf-query -c xfwm4 -p /general/use_compositing
   xfconf-query -c xfce4-panel -lv | grep -iE "background|opacity"
   grep -i opacity ~/.config/xfce4/panel/whiskermenu-*.rc
   ```
3. Fix defects 1–4. Keep the functional-vs-theme split: visual styling belongs in
   `themes/windows7-xfce/` with `mkForce`, never in `modules/home-manager/xfce/`.
4. `sudo chown -R insideabush:users /home/insideabush/nixos-config`, then `rebuild`.
5. **Run `win7-xfce-refresh`** — xfconfd reads its XML only at startup and lingers past logout,
   so a live XFCE session will not show your change until the daemons are reloaded. If anything
   still looks stale after that, log out and back in before concluding the change failed.
6. Screenshot again and **show Blaney both**. The amount of transparency is his call — offer him
   a couple of alpha values and use the one he picks.
7. Check the gaming interaction from defect 2: launch something fullscreen, confirm compositing
   drops, quit, confirm the glass comes back.
8. Confirm every monitor's taskbar got the treatment, not just the primary.
9. Commit, **open a PR** against `main`, and stop. Do not merge — lando does that.

**Done when:** Blaney's taskbar is visibly translucent with the Win7 glass look on every
monitor, the Start menu is translucent and properly themed, he says it looks right, and
fullscreen games still turn compositing off.

## Traps

- **`win7-xfce-refresh` after every rebuild.** Skipping it is how a working change gets
  diagnosed as broken. See `docs/remote-xfce-rdp.md`.
- **`xfwm4.xml` and `xfce4-panel.xml` are read-only symlinks into the Nix store** (written by
  `xdg.configFile`). An `xfconf-query --set` against them changes the running session but cannot
  persist, so a value you "fixed" by hand will be gone next login. Fine for experimenting — the
  fix has to land in the `.nix` file.
- **Don't drag or right-click-configure the panel to try settings.** The whole channel is
  declaratively owned; the next rebuild reverts it and you will lose track of what you proved.
  Experiment with `xfconf-query`, then write the result into `panel.nix`.
- **Don't touch `use_compositing` in `gaming-compositor.nix`.** It is correct; it fixes a real,
  measured stutter.
- The theme is shared with gaming-pc (`themes.xfce = "windows7"` there too), so anything you
  change here changes lando's XFCE session as well. That is expected for a theme fix — just
  don't hardcode anything Blaney-specific into the shared theme; host-specific values belong in
  `customConfig.homeManager.themes.xfcePanel`.
- Eval all hosts before opening the PR (the loop in `CLAUDE.md`'s Task Workflow), not just
  blaney-pc — these files are shared modules.
