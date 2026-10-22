<!-- ~/nixos-config/docs/xbox360.md -->
> **Read this when**: working on the xbox360 rice ("Xbox 360 Dashboard" login session) —
> its Quickshell shell, controller daemon, dashboard menus, Guide, pages or session
> plumbing. The session mechanism itself (a second Hyprland config, `hypr-rice` guards)
> is in [theming.md](theming.md#session-scoped-rices-xbox360).

# Xbox 360 Dashboard rice

A couch-and-controller desktop recreating the original 2005 Xbox 360 "Blades" dashboard,
focused on gaming and media. It is its own login session next to century-series, enabled
with `customConfig.homeManager.themes.hyprlandExtraSessions = [ "xbox360" ]`.

**Base every visual on the reference captures** in `Captures/xbox360-examples` on the NAS
(blades, submenu, guide, guide-submenu, notification, keyboard) — not on memory. The
geometry in `themes/xbox360/colors.nix` `layout` was measured off them.

## The model

| Place | What it is |
|---|---|
| **Dashboard** | Hyprland workspace `name:dashboard` on the primary monitor. The five blades are **menus** (rows, description, gamer card, legend); nothing tiles here. |
| **App workspaces** | Launching from a menu switches to a NEW numbered workspace and runs the app there. It is drawn as the console's full-width "submenu" frame in the colour of the blade it came from, titled with the app's name. |
| **Pages** | Full-screen views opened from a row (Downloads, ...), on the dashboard workspace, in the same submenu frame. |

- Getting back: Guide → Y, or SUPER+Home / SUPER+Space (`qs ipc call ui home` toggles
  dashboard ⇄ last app), or click "Xbox Dashboard" in the footer legend.
- From the dashboard, Y / the bottom pill / the legend **resumes** the last app.
- When an app's last window closes, its workspace returns to the dashboard.
- A window that opens ON the dashboard (started from elsewhere) is moved to a workspace
  of its own.
- An app that hasn't shown a window yet gets the console's loading ring; after 30 s a
  hint that it may not be coming.

## Blades

| Blade | Rows (from `menus.nix`, built from `customConfig.apps.programs`) |
|---|---|
| Marketplace | System Update, Rebuild (in a terminal), Downloads (page: NAS Transmission) |
| Xbox LIVE | the browsers, YouTube |
| Games | Steam Big Picture, Steam, the alt launcher |
| Media | Music (Spotify), Pictures, Videos, Visualizer |
| System | File Manager, Terminal, Task Manager, Audio, Bluetooth, Network |

A row whose role has no command on the host is dropped. Per-host options:
`themes.xbox360.transmissionUrl` (Downloads) and `themes.xbox360.jellyfinUrl` (Videos).

## Controller (`pad/xbox360-pad.py`)

A Python daemon (python-evdev) started from the rice's `exec-once`, log in
`/tmp/xbox360-pad.log`. It reads every pad that has both `BTN_SOUTH` and `BTN_MODE`
(xpad and xpadneo expose Guide as `BTN_MODE`), rescanning every 2 s for hotplug.

| Input | Where | Does |
|---|---|---|
| Guide tap | everywhere | the Guide (until the Guide blade exists: dashboard ⇄ last app) |
| Guide held 1 s | everywhere | `power` to the shell (the turn-off prompt) |
| Guide + LB / RB | everywhere | previous / next app workspace (numbered, with windows), wrapping |
| Guide + D-pad / left stick | everywhere | `movefocus` |
| Guide + Y / X | everywhere | dashboard / on-screen keyboard |
| Guide + Back / Start | everywhere | close window / toggle fullscreen |
| everything | shell UI up | to the shell over the socket, directions repeating (300/100 ms); the pads are **grabbed** so the app underneath doesn't also react |
| right stick, RT/LT, RS click | non-gamepad apps | pointer, left/right click, middle click |
| left stick, D-pad | non-gamepad apps | scroll, arrow keys |
| A / B / X / Y | non-gamepad apps | Enter / Escape (browsers: Alt+Left) / Backspace / keyboard |
| LB / RB | non-gamepad apps | previous / next tab |

Apps in `passthrough` (session.nix `padConfig`: Steam and its games, mpv, Heroic,
emulators, Moonlight, Jellyfin players) and anything fullscreen get the pad untouched.
The emulation is one `uinput` device; `modules/nixos/desktop/hyprland.nix` loads `uinput`
and tags it `uaccess` when the rice is enabled, so it never depends on Steam's udev rules.

The link: the daemon serves `$XDG_RUNTIME_DIR/xbox360-pad.sock`; the shell connects
(`ShellState`, retrying every 2 s) and reads `btn <name>`, `guide`, `power`, `dashboard`,
`keyboard`; it writes `ui 1|0` whenever any input handler becomes (in)active.

X/Y: xpad and xpadneo report X as `BTN_X` (== `BTN_NORTH`) and Y as `BTN_Y` — the
opposite of the gamepad spec's compass names. `swapXY` in the config flips it if a driver
ever follows the spec.

**The on-screen keyboard** (`Keyboard.qml`, `keyboard.png`) types each key straight into the
focused window with `wtype`; its layer never takes keyboard focus, so the app keeps it.

**Testing without a controller**: a fake pad over uinput in the VM — see "Testing".

## Shell layout (`themes/xbox360/shell/`)

| File | Role |
|---|---|
| `shell.qml` | root: a `Frame` per screen; `IpcHandler` target `ui` (`input`, `home`, `dashboard`, `resume`, `launch`) |
| `ShellState.qml` | singleton: blade/row selection, pages, app-workspace `meta` (persisted to `$XDG_RUNTIME_DIR/xbox360-workspaces.json`), launch/resume, sounds, the input-handler stack |
| `Frame.qml` | one screen: mode `blades` / `page` / `app`, the morph between them, exclusive zones, loading ring |
| `DashboardMenu.qml` | TOP-layer window over the card with exclusive keyboard while the dashboard shows; routes buttons |
| `BladeMenu.qml`, `MenuRow.qml`, `GamerCard.qml`, `BladeLogo.qml` | a blade's menu |
| `BladeTab.qml`, `BladeBands.qml`, `ButtonGlyph.qml`, `BladeSurface.qml` | bands, header/footer + legend, button glyphs, the shader |
| `Page*.qml` | full-screen pages, registered by id in session.nix `pages` |
| `Geometry.js` | all geometry; `Config.js` is generated by session.nix |

**Input** is one vocabulary everywhere: `a b x y up down left right lb rb lt rt start back`.
The keyboard maps onto it in `DashboardMenu` (arrows, Enter=A, Esc=B, Tab=RB, PgUp/Dn=LT/RT),
the controller daemon sends it over IPC, and whatever is on top registers a handler with
`ShellState.pushHandler` — the newest active one gets first refusal.

**Geometry**: one uniform scale fits the 1280×720 reference frame to the screen, so a
portrait or 16:10 screen gets a taller frame `H` rather than a stretched one. Every edge is
one even arc (24 ref px deep) — `curve` in colors.nix; `blade.frag.in` is generated from
the same knots so the shader's mask matches the polygons, and is compiled to `.qsb` at build
time. The app/page frame is the same panel with curve 0 and the bands dealt off-screen,
which is what makes the dashboard → app transition a morph.

## Gotchas

- **Hover selects only on real pointer motion** (`ShellState.pointerMoved`). When a menu
  slides in under a parked pointer, Qt reports motion *relative to the moving item*, so a
  couch user's idle mouse picked rows at random — including the very first reading after
  start, which is only a baseline.
- **Exclusive keyboard on a layer** only while the dashboard shows; otherwise the app gets
  the keyboard. Compositor binds (SUPER+…) still work either way.
- The functional layer's wallpaper daemon is filtered out of the rice's `exec-once`: a
  second background-layer surface would stack unpredictably with the frame.
- `Quickshell.iconPath(name, true)` returns "" for a missing icon — fall back explicitly.
  The shell pins `//@ pragma IconTheme Papirus`; without it Qt's empty default theme is used.
- QML singletons: Quickshell registers `pragma Singleton` files itself; plain `qmllint`
  needs a generated `qmldir` (`singleton ShellState ShellState.qml`) or it reports every
  member as missing.

## Testing

Use `vm-sandbox` (it has the rice enabled) headless over QMP — a nested Hyprland renders
nothing while the real session is locked. For a quick boot straight into the rice, add a
temporary `services.displayManager.defaultSession = lib.mkForce "hyprland-xbox360";` to
`hosts/vm-sandbox/desktop.nix` and **remove it before committing**.

Iterating on QML without rebuilding the VM: build only
`…home-manager.users.lando.xdg.configFile."quickshell/xbox360".source`, copy it into the
guest over `ssh -p 2222`, point `~/.config/quickshell/xbox360` at the copy and restart
`qs -c xbox360` (keep the name: keybinds call `qs -c xbox360 ipc …`). Kill the old shell
with `pkill -f 'quickshell-0[.]3'`, **not** `pkill -x qs` — the process is
`.quickshell-wrapped`, so `-x` misses it, and two shells mean doubled exclusive zones
(windows squeezed to a sliver) and doubled sounds.

Testing the controller in the VM: create a fake Xbox pad inside the guest with python-evdev
`UInput` (BTN_SOUTH…BTN_MODE, sticks −32768…32767, triggers 0…1023, hat −1…1, named
"Xbox Wireless Controller"), using the daemon's own python env (it has evdev), and feed it
`tap a` / `down guide` / `axis rx 30000` style commands through a FIFO. The daemon picks
it up like real hardware. It proves the routing, the grab, the chords and the emulation —
not xpadneo's real button codes, which still need a real controller.
