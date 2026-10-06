<!-- ~/nixos-config/docs/theming.md -->
> **Read this when**: working on Plasma/SDDM/Hyprland themes, or adding/editing any
> `modules/home-manager/themes/*` module. The functional-vs-theme split below is the
> rule that governs every Wayland component module in this repo.

# Working with Themes

## Plasma Themes
- `windows7` / `windows7-alt` - Complete Windows 7 recreation with custom plasmoids
- `bigsur` - macOS Big Sur appearance
- `aerothemeplasma` - Base Aero theme system

Theme configuration is set via `customConfig.homeManager.themes.kde`.

## Custom SDDM Themes
Configure via `customConfig.desktop.displayManager.sddm.customTheme` with wallpaper, colors, and styling options.

## Hyprland Themes
- `future-aviation` - Sleek aerospace aesthetic with modern fighter jet inspiration
- `century-series` - Cold War aviation cockpit theme (F-100 through F-106, MiG-17/19/21)

Theme configuration is set via `customConfig.homeManager.themes.hyprland`.

### century-series night mode

`century-series` carries a second palette — **night-mission stealth** (F-117/B-2): red
and warm-ember accents on near-black, with no value where blue exceeds red. It switches
automatically at sunset and back at sunrise, animated over `transitionSeconds`.

```nix
customConfig.homeManager.themes.centurySeries.night = {
  enable = true;          # default
  mode = "auto";          # auto | day | night (initial seed only)
  transitionSeconds = 90;
  steps = 10;             # interpolation steps; 1 = effectively instant
};
```

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
| Waybar | rewrite `~/.config/waybar/century-palette.css` + **one** `SIGUSR2` | yes, but a single crossover at the ramp midpoint |
| CRT screen shader | `hyprctl keyword decoration:screen_shader` to a per-step path | yes, only when the opt-in filter is already on |

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

### Theme Modules (`modules/home-manager/themes/*/`)
**Conditionally active** when theme is selected. Provide only:
- **Visual styling**: Colors, fonts, borders, animations
- **Theme-specific overrides**: Custom formats, icons, CSS styling
- **Wallpapers and assets**: Theme-specific media files
- **Aesthetic configuration**: Gaps, rounding, shadows, effects
- **Priority overrides**: Use `mkForce` for conflicting visual settings

Examples:
- `themes/century-series/hyprland.nix` - MFD borders, cockpit colors, tactical animations
- `themes/century-series/waybar.nix` - Aviation terminology, instrument panel styling

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

