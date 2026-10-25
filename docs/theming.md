<!-- ~/nixos-config/docs/theming.md -->
> **Read this when**: working on Plasma/SDDM/Hyprland themes, or adding/editing any
> `modules/home-manager/themes/*` or `modules/home-manager/hyprland/desktops/*` module. The functional-vs-theme split below is the
> rule that governs every Wayland component module in this repo.

# Working with Themes

## Plasma Themes
- `windows7` / `windows7-alt` - Complete Windows 7 recreation with custom plasmoids
- `bigsur` - macOS Big Sur appearance
- `aerothemeplasma` - Base Aero theme system

Theme configuration is set via `customConfig.homeManager.themes.kde`.

## Custom SDDM Themes
Configure via `customConfig.desktop.displayManager.sddm.customTheme` with wallpaper, colors, and styling options.

## Hyprland desktops (themes)
Each is a directory under `modules/home-manager/hyprland/desktops/`, picked with
`customConfig.homeManager.hyprland.desktops` — see [Hyprland desktops](#hyprland-desktops).
- `future-aviation` - Sleek aerospace aesthetic with modern fighter jet inspiration
- `century-series` - Cold War aviation cockpit theme (F-100 through F-106, MiG-17/19/21)
- `glade` - insideabush's pixel-art forest as the whole desktop; structural as well as
  visual — see [The glade theme](#the-glade-theme)
- `xbox360` - the 2005 Xbox 360 "Blades" dashboard: its own shell rather than a theme
  of the usual bar-and-windows session — see [xbox360.md](xbox360.md).

### century-series night mode

`century-series` carries a second palette — **night-mission stealth** (F-117/B-2): red
and warm-ember accents on near-black, with no value where blue exceeds red. It switches
automatically at sunset and back at sunrise, animated over `transitionSeconds`.

```nix
customConfig.homeManager.themes.centurySeries.night = {
  enable = true;                 # default
  mode = "auto";                 # auto | day | night (initial seed only)
  transitionSeconds = 90;        # the ramp the SUN triggers
  manualTransitionSeconds = 10;  # the ramp a PERSON triggers
  steps = 10;                    # interpolation steps; 1 = effectively instant
};
```

**Two ramps, deliberately.** Waybar cannot be restyled gradually (see the traps below),
so the bar crosses over exactly once, and *when* is the only lever:

| Trigger | Duration | Waybar crosses |
|---|---|---|
| the sun | `transitionSeconds` (90) | the midpoint, so the swap sits inside the compositor fade |
| a person | `manualTransitionSeconds` (10) | the **first step** — measured ~2s to the bar changing |

Nobody is watching a sunset; someone who just clicked the widget is. Crossing at the
midpoint of even the short ramp measured ~10s, because each step's `hyprctl` work costs
more than the sleep between steps — shortening the ramp alone was not enough.

Whoever *starts* the ramp writes `manual` or `sun` to `~/.cache/century-night-trigger`,
because the ramp service is started identically either way and nothing inside it knows
whether a person is waiting. `century-night now day|night` skips the ramp entirely.

A `custom/century-night` waybar widget sits beside the hyprsunset one — the two are
the layered halves of the same idea, so seeing both states together tells you which is
responsible for what you are looking at. It shows the APPLIED side (DAY/NGT), goes
dashed while ramping, and turns caution-yellow when pinned by hand. Click toggles,
right-click returns to `auto`. `SUPER+CTRL+N` does the same from the keyboard.

With `night.keyboard` (default on) and ckb-next enabled, the keyboard moves to its RED
cycle entry at night and back by day. It writes the same `~/.cache/ckb-color-state`
that `SUPER+CTRL+K` writes, so a manual cycle during the night sticks until the next
boundary rather than being fought.

Runtime control: `century-night {status|day|night|auto|toggle|reconcile}`, plus
`century-night now day|night` for an un-animated flip (the testing hook) and
`century-night init` for the login/activation path. A runtime mode change wins over
`mode` from then on; `century-night auto` hands control back to the sun.

This is **independent of, and layered under, hyprsunset**: hyprsunset shifts colour
temperature, night mode shifts the palette itself. They share one boundary —
`hyprsunset-isday` from `modules/home-manager/scripts/hyprsunset-solar.nix` — but keep
separate state, because hyprsunset's reconciler bails out in `manual`/`disabled` mode
and the theme must keep switching regardless.

Because the two layers compound, a red palette under a 2500 K CTM can wash out the
difference between warning and accent. If night mode reads as too uniformly red, raise
`homeManager.services.hyprsunset.nightTemp` toward 3000–3200 K rather than desaturating
the palette.

**How a build-time palette switches at runtime.** `colors.nix` exports `centuryColors`
and `centuryNightColors` under identical keys, plus `paletteSteps n`, which interpolates
between them — HSL with shortest-arc hue for chromatic accents, so green→red sweeps
through yellow and orange instead of through khaki, and straight sRGB for near-greys,
where an HSL arc would detour through purple. `night-mode.nix` pre-builds every step's
artifacts into the store and the ramp walks them:

| Surface | Mechanism | Live? |
|---|---|---|
| Hyprland borders, `dim_strength`, `blur:brightness` | one `hyprctl --batch` per step | yes, interpolated every step |
| Waybar | rewrite `~/.config/waybar/century-palette.css`, then **restart the bar once** | yes, a single crossover at the ramp midpoint |
| Wallpaper | one `awww img -t fade --transition-duration` up front | yes, awww animates its own crossfade alongside the walk |
| CRT screen shader | `hyprctl keyword decoration:screen_shader` to a per-step path | yes, only when the opt-in filter is already on |

### Application colours

Apps that read their config only at launch live in
`hyprland/desktops/century-series/app-themes.nix` — one generator per app, each a function of the
palette, so the day module and the switcher build from the same source and cannot drift.
`night-mode.nix` lists them in `swappable` and `century-apps-apply day|night` installs
the right variant. Adding an app is one generator plus one list entry.

| App | Mechanism | Catches up |
|---|---|---|
| kitty | generated `century-colors.conf`, `include`d by the theme; `SIGUSR1` | immediately, in open terminals |
| starship | generated `~/.config/starship.toml` | next prompt |
| dunst | `dunstctl reload <path>` — no file swap at all | next notification |
| rofi | an `@import`ed `century-colors.rasi` — home-manager's `toRasi` emits a top-level `@import` key before everything else | next launch |
| wlogout | `@import`ed GTK palette, plus 12 regenerated SVG tiles | next launch |
| swaylock | generated `~/.config/swaylock/config` | next lock |
| btop, yazi, imv | generated theme files | next launch |
| zathura | `include`d `century-colors` | next launch |
| browser userChrome | CSS custom properties in an `@import`ed file | next browser launch |
| ckb-next keyboard | selects index 2 (RED) of the existing cycle | immediately |

**kitty is the one place a key changes meaning, not just hue.** `term-fg` is phosphor
green by day and red by night, because a green-on-black CRT is the day conceit and red
instrument lighting is the night one. Two deliberate choices around it: night body text
(`#e8513a`) is a *softer* red than `warning-red` (`#ff1f14`) so error output still stands
out against it, and ANSI green becomes **ember** (`#d98a2b`) rather than another red —
otherwise `ls` directories and `git` additions would be indistinguishable from errors.

**dunst's night config is the day config with its colours substituted**, not a second
render of the settings attrset. Re-rendering looked cleaner but silently drops what
home-manager adds on the way out — notably the computed `icon_path`, without which night
notifications lose their icons — and writes `true`/`false` where home-manager writes
`yes`/`no`. Only the nine palette keys dunst actually uses are substituted, because
several palette values are shared between keys with *different* night values (`#7fda89`
is both `accent-green` and `term-fg`), so a blanket hex replacement would be ambiguous.
That list has to stay in step with `mkDunstSettings`.

Everything the theme styles follows the switch, including the Firefox/LibreWolf
userChrome — that one via CSS custom properties in an `@import`ed file, which
Gecko reads only at startup, so it lands on the next browser launch.

> **dunst vs swaync.** The functional layer enables swaync and this theme enables
> dunst. Both units declare `BusName=org.freedesktop.Notifications`, and systemd
> refuses to load **either** when two units claim one bus name — so the host ran no
> notification daemon at all and every `notify-send` failed with `NameHasNoOwner`,
> silently. The theme now `mkForce`s `services.swaync.enable = false`, since it styles
> dunst in detail and does not style swaync. If you ever want swaync back, turn dunst
> off in the theme rather than enabling both.


#### Gotchas found after first live use

Four bugs that only showed up once the widget and keybind were in a real session:

- **rasi rejects a `@reference` INSIDE a compound value.** `highlight: bold @accent-amber;`
  is a parse error that takes down the *entire* rofi theme — rofi then refuses to launch
  and shows an error window. A reference as the **complete** value is fine, so the whole
  `bold <colour>` compound lives in the variable (`hl-accent`, `hl-match`) instead.
  **Validate any rasi change headlessly** — it needs no display and would have caught
  this immediately:
  ```bash
  rofi -dump-theme -theme ~/.local/share/rofi/themes/custom.rasi
  ```
- **The waybar restart must be serialised.** Two restarts can legitimately overlap — a
  toggle starting a ramp while the 5-minute reconciler is mid-re-assert — and without a
  lock each spawns its own `waybar-start`, leaving **duplicate bars stacked on screen**.
  It now takes an `flock`, kills any in-flight wrapper as well as the bars, waits for
  them to actually exit, and holds the lock until the new wrapper has `exec`ed.
- **`toggle` must decide from the MODE, not the phase file.** Phase records what was
  *applied* and can be stale — most obviously when no session was running to apply it.
  Keying off it made a click pin the side you were already on, so the first left-click
  appeared to do nothing and only worked after a right-click (`auto`) had resynced.
- **The ramp must not no-op when phase already equals target.** It used to `exit 0`
  there, which skipped the wallpaper call further down — so an explicit request changed
  nothing *and* left the wallpaper behind. It now applies the target once, without
  animation, since everything it does is idempotent.

### Wallpaper engine

`customConfig.desktop.hyprland.wallpaperEngine` picks the daemon, and defaults to
`awww` whenever century-series night mode is on. **hyprpaper 0.8.x dropped its IPC
socket entirely** — 0.7.5's binary contains `hyprpaper.sock`, `listloaded` and
`listactive`, 0.8.4 contains none of them — so with hyprpaper the wallpaper can only be
changed by restarting the daemon, which blinks. `awww` (nixpkgs' current name for
`swww`; the `swww` attribute is an alias that warns) keeps a daemon with a per-monitor
GPU crossfade.

The choice lives in the *functional* layer because starting a daemon is functional, not
styling; the theme only reads it. `services.hyprpaper` is `mkIf`-gated on the same
option so the two daemons never both run.

Both wallpaper sets and the per-monitor assignment live in
`hyprland/desktops/century-series/wallpapers.nix`, shared by `hyprland.nix` (which feeds the day
set to hyprpaper and links the files) and `night-mode.nix` (which needs both). The night
set mirrors the day set slot for slot, so each display keeps its character across the
switch — hero airframe on primary, cockpit on secondary, portraits stay portrait.

Two things the applier has to handle: `awww -o` takes **output names** (`DP-1`), while a
monitor identifier may be `desc:<description>`, which only Hyprland can resolve — and it
is a **prefix** match, because Hyprland appends a serial to `.description`. And the
daemon is started from the same `exec-once` batch, so the applier retries `awww query`
for up to 10s at login rather than leaving the desktop bare. A missing night image falls
back to the day one with a single notification, never to a blank screen.

> **Changing `wallpaperEngine` needs a fresh Hyprland session.** `exec-once` only runs
> at session start, so a rebuild that switches the engine leaves the *old* daemon
> running and never launches the new one. Colours still switch — those go through
> `hyprctl` to the live compositor — but wallpapers silently do not, which reads as a
> broken feature. The applier now notices awww is unreachable and says so once per
> session via `notify-send`. To fix it without logging out: kill `hyprpaper`, start
> `awww-daemon`, then run `century-wallpaper-apply night 3`.

So the compositor interpolates continuously while the bar changes exactly once,
halfway through, which is why the whole thing still reads as one event.

Five traps here are load-bearing, and every one was verified in a live session rather
than assumed:

- **Waybar can only be restyled by `SIGUSR2`, and only once per transition.**
  `reload_style_on_change` does *not* fire for `@import`ed files (tested with both an
  atomic rename and an in-place append), and the top-level stylesheet is an immutable
  store symlink so it never changes either — the option is useless here and is
  deliberately not set. `SIGUSR2` is a full reload that recreates the bars: one is
  clean, but **eleven in a row (one per ramp step) made both bars disappear entirely.**
- **And `SIGUSR2` is unusable once there are TWO bars**, which `waybar-start` runs
  whenever the launcher is enabled. A reload sends the second process down
  GApplication's D-Bus "remote" path — both share one application id — and GLib aborts
  it with `g_application_impl_command_line: assertion failed: (object_id != 0)`.
  Staggering the signals does not help; it is structural, not a race. The launcher bar
  dies and leaves a **zombie**, which is easy to miss because `pgrep -c waybar` still
  counts it. So the bar is RESTARTED once per transition instead (via `waybar-start`,
  which splits the config and honours the launchbar-hidden state) — a sub-second blink,
  correct with either one bar or two. A single-bar VM never surfaces any of this.
- **`pkill waybar` also matches the `waybar-start` wrapper**, whose comm is
  `waybar-start`. Both the restart and the widget poke therefore match on
  `waybar --config` instead, which only the real bars carry in their argv. Hitting the
  wrapper in its brief window — after it has backgrounded the launcher bar but before
  it `exec`s the main one — leaves a launcher with no main bar. With `pkill -RTMIN+N`
  it is worse: the wrapper has no handler for that signal, so it is simply killed.
- Waybar's stylesheet stays a declarative store symlink; only the small
  `@define-color` palette it `@import`s gets rewritten. The import URL **must be
  absolute** — a relative one resolves against the store path, not `~/.config/waybar` —
  and a **missing** import makes GTK reject the *entire* provider (unstyled bars), which
  is why `home.activation` guarantees the file exists and every write is atomic
  (`install` to a temp name, then `mv`).
- **Never append alpha to a GTK named colour.** `@c_x40` parses with *no error* and
  silently resolves to nothing. Use `alpha(@c_x, 0.251)`.
- `@define-color` rejects 8-digit hex, so values carrying alpha (e.g. `glass`) are
  emitted as `rgba()`.
- The ramp must **not** touch `windowrule border_color`: `hyprctl keyword windowrule`
  *appends* rather than replaces, so ramping it would leak dead rules all day.
- `hyprctl` needs `HYPRLAND_INSTANCE_SIGNATURE`, which is **not** in the systemd user
  environment (`hyprland/functional.nix` imports only `WAYLAND_DISPLAY`, `DISPLAY`,
  `XDG_CURRENT_DESKTOP` and `XDG_MENU_PREFIX`). The step script discovers it from
  `$XDG_RUNTIME_DIR/hypr/`, the same way the `claude-rwr` widget does; without that the
  ramp runs from its service, repaints the bar, and silently never moves a border.

The reconciler re-asserts the current phase on every 5-minute poll even when nothing
changed, because `hyprctl keyword` values do not survive the `hyprctl reload` that every
rebuild triggers.

Each ramp step is a distinct store path on purpose: Hyprland caches a compiled screen
shader by path, so rewriting one file in place would never recompile.

## Hyprland desktops

A **Hyprland desktop** is a whole Hyprland session: the shared functional layer
(`hyprland/functional.nix`, swayidle, …) plus the desktop's own settings, startup and
programs. A host lists the ones it offers, and each gets its own display-manager entry:

```nix
customConfig.homeManager.hyprland.desktops = {
  enabled = [ "century-series" "xbox360" ];  # one login entry each
  default = "century-series";                # the plain "Hyprland" entry
};
```

Switching desktops is log out → pick the entry, or live with Super+Shift+D (below); no
rebuild. `default` defaults to the
first of `enabled`, and must be one of them; a host with no Hyprland desktop leaves both
unset.

- **Layout.** `modules/home-manager/hyprland/desktops/<name>/` is a desktop: every
  subdirectory is imported automatically by `hyprland/desktops.nix`. It holds:
  - `default.nix` / its modules, which set `hyprDesktops.<name>.{settings,extraConfig,
    plugins,transformSettings,leaveExtraConfig}` (declared for every directory by
    `desktops.nix`, from `desktops/lib.nix`) — **never** `wayland.windowManager.hyprland.
    {settings,extraConfig,plugins}`, which an assertion enforces. Each module gates on
    `(import ../lib.nix { inherit lib; }).state customConfig "<name>"`: **`enabled`** for
    its `hyprDesktops` settings and packages, **`isDefault`** for anything written to a
    global app config (waybar, rofi, kitty, GTK, dunst, a wallpaper service, …);
  - `meta.nix`, a plain attrset the NixOS side reads (`label` = the login entry's name,
    `needsUinput`). `modules/nixos/desktop/hyprland.nix` turns every enabled non-default
    desktop into a `sessionPackages` entry and gates `uinput` on `needsUinput`.
- **Config.** The default desktop's `hyprDesktops.<name>` definitions are forwarded,
  priorities intact, into `wayland.windowManager.hyprland.*`, and the file home-manager
  renders from them is written to `~/.config/hypr/desktops/<default>.conf` instead of
  `hyprland.conf` (its own entry is disabled). Every other enabled desktop is rendered by
  `hyprland/desktops.nix` to `~/.config/hypr/desktops/<name>.conf`, by re-merging the
  individual definitions of `wayland.windowManager.hyprland.{settings,extraConfig,plugins}`
  (`options.….definitionsWithLocations`) — all but the forwarded ones, i.e. the
  functional layer — with the desktop's own, priorities intact (functional values set
  without `mkDefault` need `mkForce`). `transformSettings` edits the merged result of a
  non-default desktop (xbox360 drops the wallpaper daemon and points the lock/power binds
  at its shell); `leaveExtraConfig` goes into the default desktop's config to undo state
  it leaves behind (xbox360's TV Mode).
- **A desktop's `exec-once` lines go in its `extraConfig`**, never `settings."exec-once"`:
  functional.nix sets that list with `mkDefault`, so a plain definition replaces it wholesale.
- **Session: `hyprland.conf` picks the desktop by environment.** Every session starts on
  `~/.config/hypr/hyprland.conf`, which only `source`s one of the desktop configs inside
  `# hyprlang if` blocks: the default's under `!HYPR_DESKTOP_AWAY`, each other's under
  `HYPR_DESKTOP_IS_<name>` (`-` → `_`, `desktops/lib.nix` `envVar`). With neither set (the
  plain "Hyprland" entry, a bare `start-hyprland`) it is the default desktop; a desktop's
  own entry exports both and runs `start-hyprland`. hyprlang re-reads the environment on
  every parse, so `hyprctl reload` follows a change to them. Keep the blocks flat:
  hyprlang only honours the innermost `if`, so a nested one is evaluated on its own.
- **Which desktop is live: systemd user targets.** Every desktop's config starts with
  `hypr-desktop session-start <name>`, which imports the compositor's
  `HYPRLAND_INSTANCE_SIGNATURE` into the user manager and starts
  `hypr-desktop-<name>.target`. Each target `BindsTo` `hypr-desktop-session.service`, which
  waits on the compositor's pid (read from its `hyprland.lock`), so the target stops when the session
  ends; targets `Conflict` with each other. `hypr-desktop current` prints the live one
  (empty outside a Hyprland session, and for the moment at login before it is up);
  `hypr-desktop list` lists them. Both units are `X-SwitchMethod = keep-old`, so a rebuild
  never takes a running desktop's units down.
- **A unit that belongs to one desktop** merges in `desktops/lib.nix` `bindTo "<name>"`
  (`PartOf` + `WantedBy` the target): it starts with that session and stops when it ends.
  So far: xbox360's controller daemon `xbox360-pad.service`, century-series'
  `century-night-schedule.timer` and `century-night-monitor-watch.service`. Units stopping
  with their session is why nothing else needs to check what is live — prefer this to
  `exec-once` for anything that would otherwise outlive the compositor.
- **A desktop's own `exec-once` lines** (in `hyprDesktops.<name>.extraConfig`) are rewritten
  to `hypr-desktop run <name> '<command>'`, which runs them in a transient systemd scope
  `PartOf` the desktop's target. So what they start (xbox360's shell, `glade-desktop`)
  also stops with the desktop, at logout or on a switch. The functional layer's lines are
  not wrapped: they belong to every desktop.
- **Switching live: `hypr-desktop switch <name>`**, or `hypr-desktop pick` (Super+Shift+D
  when more than one desktop is enabled) for a rofi menu. It loads the new desktop's
  plugins, sets the selector variables and the session environment (`PATH` with its app
  wrappers, `HYPR_DESKTOP_APPS`, `KITTY_CONFIG_DIRECTORY`, `GTK_THEME`) with
  `hyprctl keyword env`, runs a plain `hyprctl reload`, unloads the old desktop's
  plugins, and starts the new target (the old one stops, with its units and scopes).
  Then it does what a reload does not: runs the `exec-once` lines the old config lacked
  plus the old desktop's `leaveExtraConfig` (xbox360's moves each display off its
  dashboard), kills backgrounded store binaries the new config lacks (the wallpaper
  daemon, going into xbox360), and restarts or stops waybar.
  - **Never `hyprctl reload full-reset`**, the only reload that re-reads
    `HYPRLAND_CONFIG`/the config path: in Hyprland 0.55.4 it crashes the compositor in
    `CConfigValueBase::flushCaches`, immediately once a plugin has ever been loaded, and
    after a few uses even without one. That is why the selector exists.
  - Windows already open keep the old look (GTK/Qt/kitty read their theme at start), and
    `env =` values only the old desktop set stay set. Logging in is still the clean path.
- **Scripts shared between desktops** that must not act in some of them ask
  `hypr-desktop current` (`desktops/lib.nix` `current`): `waybar-restart` does nothing in
  a desktop with `waybar = false`, the century-night step's `hyprctl` half and
  `century-wallpaper-apply` only act in century-series (or with no desktop up yet), and
  swayidle's lock runs the live desktop's `lockCommand` (xbox360: its shell) else swaylock.
- **`waybar = false`** (xbox360) drops `waybar-start` from that desktop's rendered config.
- **Shared apps per desktop (`ownApps`).** waybar, rofi, wlogout, swaylock, kitty and the
  GTK theme each read one config, written by the default desktop. A desktop that styles
  them sets `hyprDesktops.<name>.ownApps = true` (glade, future-aviation); when it is a
  second session, `hyprland/desktop-apps.nix` evaluates home-manager again with that
  desktop as the only one (`extendModules`) and collects what that evaluation writes for
  those apps into `~/.config/hypr/desktops/<name>/`, with wrappers in `bin/` that start
  each app on its files and an `env` file (`PATH`, `KITTY_CONFIG_DIRECTORY`,
  `GTK_THEME`, `HYPR_DESKTOP_APPS`). The session's start script sources `env`;
  `waybar-start` takes that desktop's bar; swayidle locks with its swaylock. So the
  desktop's own modules stay written for the default case (`isDefault` gates, plain
  `programs.*`), and **keybinds and bar buttons call these apps by bare name** — an
  absolute store path skips the wrapper.
  Not covered: apps the default desktop keeps regardless (btop, yazi, zathura, imv,
  dunst, browser chrome), and century-series, whose night mode rewrites live palette files
  at the global paths (`~/.config/kitty/century-colors.conf`, …), so as a second session
  it wears the default desktop's apps.
- **xbox360's assets** (`pkgs/xbox360-assets`): the Convection font and the dashboard's UI cues
  (`share/sounds/xbox360/<cue>.wav`, decoded at build time), pinned to a commit of a public
  Blades recreation. The blade palette in `hyprland/desktops/xbox360/colors.nix` comes from the same
  project's DESIGN.md and has not been checked against console captures yet.
- **The xbox360 shell itself** — dashboard, menus, app workspaces, controller, Guide — is
  documented in **[xbox360.md](xbox360.md)**.
- **Testing without logging out:** on a host that enables the desktop,
  `hypr-desktop switch <name>` (and back) is the quick check, but it inherits whatever
  the previous desktop left behind, so log in to the desktop's own entry before calling a
  change done. A nested `Hyprland -c` starts but renders nothing while the outer session
  is locked (grim hangs, and headless outputs stay 0×0). Without such a host, use
  `vm-sandbox` (century-series + xbox360) headless over QMP: pick the entry in the SDDM
  session menu (bottom-left), or run `hypr-desktop switch` over SSH.

### Adding a desktop

1. `mkdir modules/home-manager/hyprland/desktops/<name>`. `desktops.nix` imports every
   directory there and declares `hyprDesktops.<name>` for it; nothing else registers it.
2. `meta.nix`: `{ label = "<Login entry name>"; }`, plus `needsUinput = true;` if it
   emulates input.
3. `default.nix`, gated on the desktop's state:

   ```nix
   # ~/nixos-config/modules/home-manager/hyprland/desktops/<name>/default.nix
   { config, pkgs, lib, customConfig, ... }:
   let
     desktop = (import ../lib.nix { inherit lib; }).state customConfig "<name>";
   in
   {
     config = lib.mkMerge [
       (lib.mkIf desktop.enabled {
         hyprDesktops.<name> = {
           settings.general.border_size = lib.mkForce 3;   # visual overrides
           extraConfig = ''
             exec-once = some-daemon &                      # stops with the desktop
           '';
           # plugins = [ pkgs.hyprlandPlugins.hyprbars ];
           # ownApps = true;                                # its own waybar/rofi/kitty/GTK
         };
       })
       (lib.mkIf desktop.isDefault {
         # global app configs: programs.waybar.style, programs.kitty, gtk, wallpapers …
       })
     ];
   }
   ```

   A user service the desktop runs should merge in
   `(import ../lib.nix { inherit lib; }).bindTo "<name>"` instead of checking what is live.
   Anything it changes outside its own config (monitors, audio, workspaces) must be undone
   in `leaveExtraConfig`, which runs when you switch away live and when the default
   desktop logs in.
4. Add `"<name>"` to a host's `hyprland.desktops.enabled` and `rebuild`. Then check both
   ways in: log in to its entry, and run `hypr-desktop switch <name>` and back to the
   default. `hyprctl configerrors` should be empty, and no bar or daemon from the other
   desktop should be left running.

## The glade theme

`customConfig.homeManager.hyprland.desktops.enabled = [ "glade" ]` (blaney-pc, mirrored on vm-blaney)
makes the Hyprland session insideabush's **Glade**: his own pixel-art forest scene
(`pkgs/glade`, pinned from `github:cblaney00/glade`, his `~/projects/hud`, see
[blaney-vibe-projects.md](hosts/blaney-vibe-projects.md#packaging-a-finished-app)) as the
desktop on both monitors, and a session he can drive with the **mouse alone** — or steer
from the keyboard — every target labelled in words. He asked for exactly that, and chose
"windows like Windows" and "everything matches the glade". It is **always night** there
(his choice): the light comes from glowing moss, mushrooms, lanterns, fireflies and little
sky-squid, not the moon, so the chrome and the apps are night too.

Unlike the other Hyprland themes it is also **structural** — it changes how the session
works, not just how it looks — so the desktop has two halves, both under
`hyprland/desktops/glade/`. Its Hyprland settings go to `hyprDesktops.glade`, which keeps
them out of every other desktop (see above).

| Piece | Where |
|---|---|
| the glade as a layer-shell surface, one per monitor (GTK + gtk-layer-shell; pygame draws off-screen), and the keyboard bridge | `wayland.py` in `github:cblaney00/glade` (`pkgs/glade`) |
| **structure** — what runs, what each click or key does: autostart, `glade-show`, `glade-ctl` + the `glade` submap, floating windows + `hyprbars`, click-to-focus, resize from edges, bar layout, rofi single-click, power menu | `hyprland/desktops/glade/desktop.nix` |
| **look** — borders and title bars, bar CSS, rofi, wlogout, lock screen, kitty, GTK/icons/cursor, pixel font (Departure Mono); all from one palette taken from the scene's name boards and glows | `hyprland/desktops/glade/{hyprland,waybar,rofi,wlogout,swaylock,kitty,gtk}.nix`, `colors.nix` |

Behaviour worth knowing before changing it:

- **The glade is on the `bottom` layer with `exclusive_zone = -1`**, so it ignores the
  bar's reserved strip and keeps its exact whole-number scale; the bar simply draws over
  its top.
- **Every place and app has a fixed name board** drawn by the glade itself (Departure
  Mono, passed to the package as `GLADE_FONT`); they never move, and the board is
  clickable as well as the object. The scene's own docs (how the lighting works, what
  each file holds) are in its `CLAUDE.md` in `~/projects/hud` on blaney-pc.
- **"Glade" button = `glade-show`.** Hyprland has no minimise, so every monitor that has
  windows moves to a fresh empty workspace (ids from 100, clear of any workspace rule);
  the windows stay where they were and the bar's `wlr/taskbar` list brings them back
  (`misc:focus_on_activate` makes that switch workspaces). The workspace numbers are not
  shown at all.
- **Keyboard steering = a Hyprland submap.** A bottom-layer surface cannot count on
  keyboard focus, so `SUPER+Home` (`glade-show && glade-ctl keys`) — or a click on the
  glade while no window is focused — turns on the `glade` submap, whose binds run
  `glade-ctl <cmd>` into `$XDG_RUNTIME_DIR/glade.ctl`: arrows/WASD walk along paths, Tab
  picks a board, Enter opens it, Home/Backspace go home/back. The glade follows Hyprland's
  event socket and resets the submap the moment a window takes focus, on launching an
  app, and after 3 idle minutes; Esc does it by hand. While it is on, a hint board shows
  the keys. (`SUPER+G` was taken by the gaming app bind.)
- **Every window floats** (`windowrule = float true, match:class .*`), `follow_mouse = 2`
  (focus on click), `resize_on_border`. Title bars come from the `hyprbars` plugin, built
  from the same nixpkgs as Hyprland; dragging the bar moves a window, double-click or
  `▢` maximises (`fullscreen 1`), `✕` closes.
- **The bar is on the main monitor only** (`output` = the `main` monitor's identifier).
  The lower monitor is the ground in front of the glade, and a bar along its top would cut
  across the path where it continues from the screen above.
- **kitty must keep the Nerd Font build of JetBrains Mono** (as century-series does): his
  Claude sessions print icon glyphs that only it carries.
- The launcher bar (`desktop.hyprland.launcher`) is turned off on blaney-pc: the glade's
  boards replace it, and the bar's "Apps" button covers everything else.
- GTK, icon and cursor options are session-global, so the XFCE session on the same host
  sees `gtk.nix` too; `themes/windows7-xfce` selects its own by name inside XFCE.

Changes here can be verified on blaney-pc itself even though it cannot run a VM — see
[test-vms-and-ci.md](test-vms-and-ci.md#testing-hyprland-without-kvm-nested-in-kwin).

## Functional vs Theme Paradigm for Wayland Components

The Wayland component architecture follows a strict separation of concerns between **functional** and **theme** modules:

### Functional Modules (`modules/home-manager/*/functional.nix`)
**Always active** when the component is enabled. Provide:
- **Essential functionality**: Keybindings, startup commands, base settings
- **Hardware configuration**: Monitor layouts, input settings
- **Service management**: Process startup, systemd services
- **Package dependencies**: Required binaries and tools
- **Default configurations**: Base module settings with `mkDefault` priority

Examples:
- `hyprland/functional.nix` - Keybindings, exec-once, monitor config, variables
- `waybar/functional.nix` - Module layout, click actions, base formatting

### Theme Modules (`modules/home-manager/themes/*/`, `hyprland/desktops/*/`)
**Conditionally active** when theme is selected. Provide only:
- **Visual styling**: Colors, fonts, borders, animations
- **Theme-specific overrides**: Custom formats, icons, CSS styling
- **Wallpapers and assets**: Theme-specific media files
- **Aesthetic configuration**: Gaps, rounding, shadows, effects
- **Priority overrides**: Use `mkForce` for conflicting visual settings

Examples:
- `hyprland/desktops/century-series/hyprland.nix` - MFD borders, cockpit colors, tactical animations
- `hyprland/desktops/century-series/waybar.nix` - Aviation terminology, instrument panel styling

### Key Principles
1. **Themes never duplicate functional settings** - Always inherit base functionality
2. **Functional modules use `mkDefault`** - Allow themes to override with `mkForce`
3. **Settings merge cleanly** - No conflicts between functional base and theme overrides
4. **Themes remain portable** - Can be applied to any host without breaking functionality
5. **Functional modules stay stable** - Theme changes don't affect core functionality

### Example Architecture
```nix
# functional.nix (always active)
bind = mkDefault [
  "$mainMod, SPACE, exec, $menu"
  "$mainMod, RETURN, exec, $terminal"
];

# theme.nix (when theme active) 
general = {
  border_size = mkForce 3;  # Override for theme
  "col.active_border" = "rgb(ff9e3b)";  # Theme colors
};
```

This ensures themes provide visual identity while maintaining core Wayland functionality.

