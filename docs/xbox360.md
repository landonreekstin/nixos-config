<!-- ~/nixos-config/docs/xbox360.md -->
> **Read this when**: working on the xbox360 rice ("Xbox 360 Dashboard" login session) —
> its Quickshell shell, controller daemon, dashboard menus, Guide, pages or session
> plumbing. The session mechanism itself (a second Hyprland config, `hypr-rice` guards)
> is in [theming.md](theming.md#hyprland-desktops).

# Xbox 360 Dashboard rice

A couch-and-controller desktop recreating the original 2005 Xbox 360 "Blades" dashboard,
focused on gaming and media. It is a Hyprland desktop with its own login entry next to
century-series (`"xbox360"` in `customConfig.homeManager.hyprland.desktops.enabled`; see
[theming.md](theming.md#hyprland-desktops)). Its config is
`~/.config/hypr/desktops/xbox360.conf`.

**Where the code lives.** The program — the Quickshell shell (`shell/*.qml`, `*.js`), the
blade shader source (`shaders/blade.frag.in`) and the Python helpers (`pad/*.py`) — is its
own repo, [`landonreekstin/xbox360-dashboard`](https://github.com/landonreekstin/xbox360-dashboard),
packaged as `pkgs/xbox360-dashboard` and checked out at `~/xbox360-dashboard` on gaming-pc.
This repo keeps everything host-specific in `modules/home-manager/hyprland/desktops/xbox360/`: `session.nix` (the
Hyprland config, the generated `Config.js`, the shader's substituted knots, each
helper's JSON config), `colors.nix`, `menus.nix`, and the Microsoft assets
(`pkgs/xbox360-assets`). Paths like `pad/…` and `Shell layout` below are in that repo. A
new `Cfg.<name>` the QML reads needs its `var` added in `session.nix` in the same change.

- **Try a change before pushing it:** set `customConfig.homeManager.themes.xbox360.devSource
  = "/home/lando/xbox360-dashboard";` in the host (never commit that line) and `rebuild`;
  or, for hot reload inside the session, follow the repo's `CLAUDE.md`.
- **Ship it:** push the repo, then bump `rev`/`hash` in `pkgs/xbox360-dashboard/default.nix`
  ([companion-repos.md](companion-repos.md#xbox360-dashboard)).

**Base every visual on the reference captures** in `Captures/xbox360-examples` on the NAS
(blades, submenu, guide, guide-submenu, notification, keyboard) — not on memory. The
geometry in `hyprland/desktops/xbox360/colors.nix` `layout` was measured off them.

## The model

| Place | What it is |
|---|---|
| **Dashboard** | Hyprland workspace `name:dashboard-<connector>`, one per display (see "Multiple displays"). The five blades are **menus** (rows, description, gamer card, legend); nothing tiles here. |
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
| Games | Games Library (page), Last Played Game, Steam Big Picture, Steam, the alt launcher |
| Media | Music (Spotify), Pictures, Videos (page: Jellyfin, when `jellyfinUrl` is set), Visualizer |
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
| Guide + LB / RB | everywhere | previous / next app workspace (numbered, with windows) on the focused display, wrapping |
| Guide + right stick | everywhere | `focusmonitor` in that direction |
| Guide + LT / RT | everywhere | the focused app to the previous / next display (`movewin` to the shell) |
| Guide + D-pad / left stick | everywhere | `movefocus` |
| Guide + Y / X | everywhere | dashboard / on-screen keyboard |
| Guide + Back / Start | everywhere | close window / toggle fullscreen |
| everything | shell UI up | to the shell over the socket, directions repeating (300/100 ms); the pads are **grabbed** so the app underneath doesn't also react |
| right stick, RT/LT, RS click | non-gamepad apps | pointer, left/right click, middle click |
| left stick, D-pad | non-gamepad apps | scroll, arrow keys |
| A / B / X / Y | non-gamepad apps | Enter / Escape (browsers: Alt+Left) / Backspace / keyboard |
| LB / RB | non-gamepad apps | previous / next tab |

The player sees this table, place by place, in **Guide → Controls** (`shell/Controls.js`). That
page is a description, not the mapping: change a button here, in `padConfig`'s mpv profile or in a
page's `handle()`, and change the matching section of `Controls.js` with it.

Apps in `passthrough` (session.nix `padConfig`: Steam and its games, mpv, Heroic,
emulators, Moonlight, Jellyfin players) and anything fullscreen get the pad untouched.
The emulation is one `uinput` device; `modules/nixos/desktop/hyprland.nix` loads `uinput`
and tags it `uaccess` when the rice is enabled, so it never depends on Steam's udev rules.

The link: the daemon serves `$XDG_RUNTIME_DIR/xbox360-pad.sock`, greets each client with
`hello` and pings every 2 s; it sends `btn <name>`, `guide`, `power`, `dashboard`, `keyboard`.
The shell writes `ui 1|0` whenever any input handler becomes (in)active. The shell judges
the link **only by the ping** (5 s of silence = down) and retries every 2 s with a **brand-new
Socket from `createObject`** — three things that did not work, all seen in the VM: a failed
Socket never retries; toggling its `connected` does not make it; a `Loader` inside the
non-visual `ShellState` singleton never instantiates; and reacting to a replaced Socket's
`connected` going false tore down the good new link, because the old one reports its
teardown late. The virtual device only releases keys it pressed.

X/Y: xpad and xpadneo report X as `BTN_X` (== `BTN_NORTH`) and Y as `BTN_Y` — the
opposite of the gamepad spec's compass names. `swapXY` in the config flips it if a driver
ever follows the spec.

**The on-screen keyboard** (`Keyboard.qml`, `keyboard.png`) types each key straight into the
focused window with `wtype`; its layer never takes keyboard focus, so the app keeps it.

**Testing without a controller**: a fake pad over uinput in the VM — see "Testing".

## Games Library and Videos

- **Games Library** (`PageGames.qml`, layout of `games-submenu.png`): `pad/xbox360-games.py`
  lists every installed game as JSON — Steam from each library in `libraryfolders.vdf`
  (`appmanifest_*.acf`, minus Proton/runtimes/redistributables, art from Steam's own
  `appcache/librarycache`, which newer Steam keeps in hashed subdirectories) and Heroic
  (Epic/GOG `installed.json`, minus DLC, icons from `~/.config/heroic/icons`). Newest-played
  first; LB/RB switch the filter tabs; A launches via `steam://rungameid/<id>` or
  `heroic --no-gui 'heroic://launch?appName=…&runner=…'` on a new app workspace.
- **Videos** (`PageVideos.qml`, `Jellyfin.qml`): signs in with **Quick Connect** (a
  six-digit code approved from any signed-in Jellyfin — no typing on a couch); the token
  lives in Quickshell's state dir (`jellyfin.json`), tied to the server URL. Tabs: Continue
  Watching, Next Up, then each movie/show library; a show drills into its episodes,
  starting at the first unwatched. A plays through `pad/xbox360-jellyfin-play.py`: mpv from
  the resume point with the item's external (Bazarr) subtitles, reporting
  `/Sessions/Playing`, `…/Progress` every 10 s (position read every 2 s) and `…/Stopped`, so
  Jellyfin keeps the resume point and marks it watched past ~90 %.
- **mpv has no SDL in nixpkgs**, so it can't read a pad itself: the daemon has per-app
  **profiles** (`padConfig.profiles`) — mpv gets A pause, B quit, X subtitles, Y progress,
  D-pad seek, LB/RB chapters, LT/RT volume, even fullscreen (a profiled app is never
  "a fullscreen game: hands off").

## Lock screen, System Update, Gamerscore

- **Lock** (`LockScreen.qml`): a real `ext-session-lock` (`WlSessionLock`) drawn as the
  console's profile sign-in, password checked by PAM through the `swaylock` service. Reached
  from the Guide's X (Sign Out), SUPER+Escape (the rice's config rewrites the functional
  `swaylock` bind to `qs … ipc call ui lock`; SUPER+BackSpace goes to Turn Off Console
  instead of wlogout), and swayidle: `services/swayidle.nix` locks through a script that
  asks the rice's shell when `$XDG_RUNTIME_DIR/hypr-rice` names one, else runs swaylock.
  That call needs `qs ipc --any-display`: a unit may not carry `WAYLAND_DISPLAY`, and `qs ipc`
  otherwise only finds shells on the caller's display. Unlock needs a keyboard.
- **Marketplace → System Update** (`PageUpdates.qml`): branch and commit of
  `~/nixos-config`, how far behind `origin/main` (as last fetched — no network), when
  `/run/current-system` last changed (the symlink's own time; its target is epoch 1), and the
  open `flake-update` PR via `gh`; Update now / Rebuild / Update and turn off run in a
  terminal on an app workspace.
- **Gamerscore** on the gamer card = total Steam hours played (`Playtime` in every
  `userdata/*/config/localconfig.vdf`), from the games scanner.

## Night Mode and TV Mode

Both are switches on the System blade (left/right or A) and in Guide → Console Settings.

- **Night Mode** (Auto / On / Off, saved in Quickshell's state dir): `colors.nix` derives a
  `night` palette under the same keys as the day one, and `Theme.qml` hands out whichever
  applies, so every consumer reads `Theme.blades` / `Theme.silver` / `Theme.guide` instead of
  `Config`. Highlighted rows keep their white wash, so their text uses `Theme.onWash()`; the
  shader's gloss, sheen and ripples scale by the `glow` uniform. Auto asks
  `century-night status` (`sun=day|night`), else the clock (7 pm to 7 am).
- **TV Mode** (`session.nix` `tvScript`, host monitor named `tv`): the TV alone, with its HDMI
  sink matched by `alsa.name` == the monitor's `edid`, since pro-audio sink numbers move. It
  writes the same `~/.local/state/hypr/disabled-monitors` that `toggle-monitor` uses, so
  `monitor-state-watcher` keeps it through a rebuild's config reload. Off restores the saved
  monitor state and output; the default session runs `off` at login.
  With Audio devices configured it goes through them instead (below): on saves the device
  in use and picks the one whose `output` is the TV's `edid` — unless the device in use is
  `keepOnTv` (the headset) — and off switches back to the saved device, mic included.

## Audio

Guide → Audio (also System blade → Audio, `qs -c xbox360 ipc call ui audio`) lists the host's
`themes.xbox360.audioDevices`: each is an output **and** a microphone, switched together, with
what is playing and recording moved along. A toast confirms; a newer audio toast replaces the
older one (`Notifications.say` with a tag) so flicking through says where the sound *is*.
X swaps left and right (century-series' `toggle-audio-flip`). With no devices listed, Console
Settings keeps the plain "Sound Output" cycle instead.

- `pad/xbox360-audio.py` does the work (`list` / `set LABEL` / `current` / `keeps-tv`).
  Outputs match `"<sink name>|<description>|<alsa.name>"` like `audioSinkMappings`, so HDMI
  ones are pinned by EDID name, never `pro-output-N`. `input = "same"` is the mic on the
  output's own card: same `alsa.card`, else the same device in the node name
  (`alsa_output.usb-X-00.*` → `alsa_input.usb-X-00.*`).
- Monitors are never microphones (a sink's monitor carries the sink's `alsa.name`), and only
  recordings of a real mic are moved — a visualizer on an output's monitor stays put.
- `Audio.qml` polls only while the Guide is open. A choice shows at once (the script takes a
  moment), and a reading started before the latest switch is dropped and re-run — otherwise a
  poll in flight puts the old device back on screen.
- gaming-pc's Headset entry matches *any* USB output (`alsa_output.usb-`) because the condenser
  mic and the webcam are input-only. Narrow it to the headset's own name once it has been
  plugged in there (`pactl list short sinks`).
- The Xbox controller's 3.5mm jack is **not** one of these: it needs `xone`, which kills the
  PowerA pad's input (see the controller notes). The headset plugs in by USB instead.

## Multiple displays

Every display is its own console screen. It can show its dashboard while another runs
an app, and two displays can both be on their dashboards.

- **One dashboard per display**: workspace `name:dashboard-<connector>`, with its own
  `Dash` (`Dash.qml`: open blade, highlighted rows, page, last app), so "Resume" on each
  dashboard means the last app on *that* display.
  - **Configured monitors**: `session.nix` pins each dashboard to its monitor with a
    `default:true` workspace rule.
  - **A VM, or a `desc:` monitor**: the shell's 0.7 s bookkeeping timer moves any display
    showing an empty, unlaunched workspace (Hyprland's own at login, or one left over
    when a display went off) onto its dashboard.
  - **Dispatching**: the dashboard is always reached with
    `focusworkspaceoncurrentmonitor`, never `workspace`, so a dashboard that drifted to
    another monitor is pulled back rather than focus jumping after it.
- **Focus decides where things open.**
  - The dashboard, apps (`launch` makes the new workspace on the focused monitor), the
    Guide, the keyboard, the notification blade, toasts and the lock screen's sign-in
    all open on the focused display.
  - They stay there while open (`ShellState.guideScreen` and co. are snapshots, not
    bindings).
  - When a display goes off, the Guide and the keyboard on it close, and a message
    moves to wherever focus is.
- **Only the focused display's dashboard takes input.** Its `DashboardMenu` alone is
  `Exclusive` keyboard and an active input handler; two exclusive layers would fight.
- **The focus cue** is the controller's ring of light beside the clock in every header
  (`RingLight.qml`): the top-left quarter lit green on the focused display, dark
  elsewhere, with a short flare when focus arrives.
- **Chords**:
  - Guide + right stick: `focusmonitor` in that direction. Hyprland resolves it from
    the real layout.
  - Guide + LT / RT: the focused app to the previous / next display, ordered left to
    right (`ShellState.moveToMonitor`). An app with one window takes its whole
    workspace, name and colour included. One window of several gets a new app workspace
    there under the same name. The display it left goes back to its dashboard.
  - Guide + LB / RB: only cycles the focused display's apps. The Guide's Open Apps
    says which screen each app is on.
- **Portrait displays get the dashboard turned a quarter**
  (`Geometry.verticalFrame`, `Frame.qml` `stage`). The landscape drawing is
  *transposed* onto the screen: bands, shader, silver gutters, curves, everything in
  `Geometry.js` unchanged. The blades stack top to bottom.
  - The header and footer stay upright across the top and bottom. They are drawn by
    `Frame` (`UprightBand`) and `BladeBands`, not the shader, whose own header/footer
    shrink to a margin via the `hb`/`fh` uniforms.
  - The band labels are transposed back so they read upright.
  - Up/down past a menu's first or last row move to the blade above/below.
  - The Guide and the keyboard size themselves for portrait screens too.
- **Guide → Displays** (also System → Displays): each configured monitor, on/off, and
  which has focus. A toggles, X focuses.
  - On/off goes through century-series' `toggle-monitor`, so it persists through
    reboots (`restore-monitors`) and rebuilds (`monitor-state-watcher`) in both sessions.
  - The last display on can't be turned off, and turning off the focused one moves
    focus first.
  - A toggle while TV Mode is on ends TV Mode without restoring (`xbox360-tv forget`):
    what's lit is the new normal.

## Shell layout (`shell/` in the xbox360-dashboard repo)

| File | Role |
|---|---|
| `shell.qml` | root: a `Frame` per screen, the overlays on the focused one; `IpcHandler` target `ui` (`input`, `home`, `dashboard`, `resume`, `launch`, `movewin`, `displays`) |
| `Theme.qml` | singleton: day/night palette (`Theme.blades`, `.silver`, `.guide`, `onWash`, `glow`) |
| `ShellState.qml` | singleton: a `Dash` per display (`dashFor`, `here`), moving apps between displays, app-workspace `meta` (persisted to `$XDG_RUNTIME_DIR/xbox360-workspaces.json`), launch/resume, sounds, the input-handler stack |
| `Frame.qml` | one screen: mode `blades` / `page` / `app`, the morph between them, exclusive zones, loading ring, the turned stage on a portrait screen |
| `Dash.qml` | one display's dashboard: open blade, rows, page, last app (Resume) |
| `Displays.qml` | singleton: Guide → Displays — monitors on/off via `toggle-monitor`, focus |
| `RingLight.qml` | the ring of light beside the clock: lit on the focused display |
| `DashboardMenu.qml` | TOP-layer window over the card with exclusive keyboard while the dashboard shows on the focused display; routes buttons |
| `BladeMenu.qml`, `MenuRow.qml`, `GamerCard.qml`, `BladeLogo.qml` | a blade's menu |
| `BladeTab.qml`, `BladeBands.qml`, `ButtonGlyph.qml`, `BladeSurface.qml` | bands, header/footer + legend, button glyphs, the shader |
| `Page*.qml` | full-screen pages, registered by id in session.nix `pages` |
| `Geometry.js` | all geometry; `Config.js` is generated by session.nix; `Controls.js` is the Guide's Controls page (what each button does, per place) |

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

- **A layer surface stays where its monitor WAS.** Hyprland places a layer when it maps and
  doesn't move it with its monitor: with auto-placed outputs (the VM), turning one display off
  slid the other over and its whole frame was drawn off-screen. `Frame` re-maps all its
  surfaces when its monitor's x/y change.
- **The shader needs a GLSL ES 3.00 variant.** On NVIDIA, Quickshell's context is GLES, so
  with only `100 es` in the `.qsb` it picked that one, which rejects the knot arrays. It then
  retried the compile every frame: no gradient (flat grey), a log growing by hundreds of
  MB, and the shell leaking to 42 GB of RAM. `qsb --glsl "300 es,100 es,120,150,330"`.
- **Leaving the Guide for a workspace goes through `ShellState.fromGuide`.** The Guide holds
  exclusive keyboard focus, and when it lets go Hyprland refocuses the window that had it,
  undoing a workspace switch made in the same moment. Inside a fullscreen game that meant
  Open Apps never left the game.
- **Steam opens Big Picture on the Guide button** unless Steam → Settings → Controller →
  "Guide Button Focuses Steam" is off. Steam reads the pad through its own driver, so the
  daemon's evdev grab cannot hide the button from it.

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

Testing Games/Videos in the VM: copy a few real `appmanifest_*.acf` files and their
`librarycache/<appid>` dirs into the guest's `~/.local/share/Steam`; for Jellyfin run a tiny
fake server in the guest (Quick Connect auto-approving after a few polls, canned
libraries/episodes, a generated mp4 **with HTTP Range support** — mp4 seeking needs it, and
without it mpv exits "Errors when loading file" — and a log of the `/Sessions/Playing*`
POSTs) and point the shell's `Config.js` `jellyfinUrl` at it. The VM's software renderer
makes mpv's default output assert (`vo_x11_init`); the helper takes the mpv binary as its
first argument, so test with a wrapper adding `--vo=wlshm`. And **never `pkill -f`/`pgrep -f`
a name that also appears in the same ssh command line** — it matches the remote shell itself.

If the fake pad misbehaves (inputs repeating on their own — it once replayed a tap every
130 ms), restart it and check the daemon by logging raw `EV_KEY` events before suspecting
the shell: that loop looked exactly like "A opens a page AND triggers its first row".
Restarting the daemon with `pgrep -f … | head -1` left a second daemon reading the same pad;
kill every match.
