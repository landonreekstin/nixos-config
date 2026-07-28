# NixOS Config Task List

Tasks are grouped by category. Reorder within a group to set priority.
Format: `- [ ] **Title** — description`

**Workflow:** Before committing any change, run `rebuild-test` locally to verify it activates cleanly. Only commit and push once it passes.

---

## System / Core

- [ ] **Update notification: sync & rebuild action button** — Extend `modules/home-manager/services/update-notification.nix` to include a dunst action button labeled "Update & Rebuild" that runs `sync && rebuild` in a terminal (or background with follow-up notification). Add a second notification on completion indicating success or failure. KDE: use `kdialog` or a `.desktop` action instead of dunstify. Gate behind the existing `cfg.enable` option.

- [ ] **Branch maintenance workflow** — Define cleanup guidelines and optionally a GitHub Actions workflow for recurring branch hygiene. Guidelines for Claude to follow when asked to do a branch audit: (1) list all remote branches with last-commit date, (2) for each stale branch (no commits in >30 days), check if its diff is already present in main via `git log --cherry-pick --left-right`, (3) categorize as: *merged/obsolete* (all commits present in main — safe to delete), *superseded* (changes exist but reimplemented differently — needs human confirm), *in-progress* (diverged, unique work — keep), (4) present a summary and wait for explicit approval before deleting anything. GitHub Actions stretch goal: a scheduled workflow (monthly) that opens a GitHub Issue listing stale branches with their categorization, so the audit is triggered automatically and the conversation happens in the issue.

- [x] **rebuild: -j flag + rebuild-test command** — Add `--max-jobs auto` to the rebuild script for parallel builds. Add a `rebuild-test` command alias that runs `nixos-rebuild test` (activates config without creating a boot entry, reverts on reboot).

- [x] **Gamemode polkit fix** — Two polkit auth windows appear when launching games. Cause: gamemode is trying to set the CPU governor but the polkit rule granting the `gamemode` group permission is missing. Add the polkit rule to the gaming profile so it happens silently.

- [x] **Plymouth boot splash** — Add Plymouth boot animation for hosts using systemd-boot. Scope: add a `customConfig.bootloader.plymouth` option with theme selection. Start with a clean minimal theme.

- [x] **Display manager "none": autostart first DE in list** — When `displayManager.type = "none"`, the current logic hardcodes Hyprland. Change it to launch whatever DE is first in `customConfig.desktop.environments` instead.

- [ ] **SDDM: suppress screensaver while media is playing** — The SDDM astronaut screensaver activates on idle even when video is playing. Add idle inhibit logic so the screensaver does not trigger while a media player has an active inhibitor (mpv, vlc, etc.). Implement via swayidle inhibit rules or a systemd-inhibit wrapper depending on DE.

- [x] **GitHub update notification**

- [x] **nh clean: home-manager generation GC** — Current `nix.gc` (weekly, `--delete-older-than 7d`) handles the system store but does NOT collect old home-manager profile generations, which accumulate as GC roots and can grow large over time. Add `nh` package and configure `nh clean all` (or equivalent `home-manager expire-generations`) on the same weekly schedule to clean old HM generations. Low priority but prevents slow disk growth on active machines.

- [ ] **Remove electron_39 → electron_40 alias** — Added in `modules/nixos/unstable-overlay.nix` as a workaround for a broken nixpkgs patch on `electron 39.8.2`. After any `flake update`, test removal by deleting the alias overlay and running `NIXPKGS_ALLOW_UNFREE=1 nix eval --impure .#nixosConfigurations.asus-laptop.config.system.build.toplevel.drvPath`. If eval passes, the upstream fix is in and the alias can be deleted.

- [x] **Nix SOPS secrets management** — Core infrastructure added: sops-nix flake input, `modules/nixos/sops.nix` imported by all hosts (age identity derived from SSH host key at runtime), `sops`, `age`, `ssh-to-age` in system packages, `.sops.yaml` key config, `secrets/` directory. See sops section below for migration tasks.

- [x] **Encrypted DNS** — Add `customConfig.networking.encryptedDns.enable` backed by `services.dnscrypt-proxy2`. Include option for resolver selection (Cloudflare, Quad9, etc.).

- [x] **Test-VM hosts + build-based CI** — Added `vm-sandbox` (kitchen-sink ricing) and `vm-blaney` (blaney-pc software mirror) throwaway QEMU hosts sharing `hosts/vm-common.nix`, launched via the `testvm <sandbox|blaney>` command (12 vCPU / 16G / virgl GPU accel). Upgraded CI: `evaluate` covers the VMs; a `build` job on the optiplex-nas self-hosted runner realizes just the fragile source-built derivations (aerothemeplasma's C++ pkgs + openrazer module) so those breaks fail CI without OOMing the NAS on incidental full-toplevel builds. VMs can't validate GPU/driver behaviour (llvmpipe). Merged in PR #87; runner online with `Restart=always` self-heal.

---

## Hardware / Peripherals

- [x] **Touchpad natural scroll (Hyprland + declarative KDE)** — Set `natural_scroll = true` in `hyprland/functional.nix` (currently hardcoded to `false`). Add a `customConfig` boolean option (e.g. `customConfig.hardware.touchpad.naturalScroll`, default `true`) so it's configurable per-host. Also declare KDE touchpad scroll direction via plasma-manager in `kde/functional.nix` — it's currently set only via GUI and not in nix. Scope: any host with a touchpad (primarily asus-laptop; conditionally apply if touchpad present).

- [ ] **Laptop battery saving mode** — Add battery optimization for laptop hosts. For ASUS laptops: surface `asusctl` power profile switching (Quiet/Balanced/Performance) as a Waybar module or Hyprland keybind and a KDE widget/shortcut. For non-ASUS laptops: enable `services.tlp` (note: conflicts with power-profiles-daemon — guard with `mkIf !config.services.power-profiles-daemon.enable`). Add a `customConfig.hardware.laptop.batteryOptimization` option. Consider: screen brightness-on-battery, WiFi powersave, NVMe ASPM. Gate all of this behind `customConfig.hardware.isLaptop`.

- [ ] **Asus-m15: AirPods Max support (librepods)** — Add librepods as a flake input (it has a Nix flake). Enable as a systemd service on asus-m15 only, gated behind a `customConfig` option. Provides ANC control, battery status, and ear detection.

- [ ] **Asus-m15: Touchpad gestures in KDE** — Configure 3-finger swipe for virtual desktop switching and 4-finger swipe for app overview using KDE Plasma 6 native gesture support (no extra package needed). Configure declaratively via plasma-manager.

- [ ] **Asus-laptop: keyboard brightness lower key not working** — Likely a hardware issue with the keyboard itself (F7 and F2 produce no keysym even in terminal, while F8 works). Defer until tested with an external keyboard to confirm whether it's a keybind or hardware problem.

- [x] **Global monitor configuration (customConfig.hardware.monitors)** — Add a `customConfig.hardware.monitors` option (list of monitor specs: name, resolution, refresh, position, orientation, scale). Default: single 1920x1080 horizontal monitor. All modules that need monitor info (Hyprland, SDDM, KDE) read from this one place instead of duplicating. Medium-large scope.

---

## Desktop — General (All DEs)

- [x] **Default browser via customConfig** — Add `customConfig.programs.defaultBrowser` option. Feed it into `xdg.mimeApps.defaultApplications` for `text/html`, `x-scheme-handler/http`, `x-scheme-handler/https`, etc.

- [x] **Declarative autostart apps** — Add `customConfig.desktop.autostart` as a list of `{command, desktops}` entries. Translate to `exec-once` for Hyprland and `~/.config/autostart/*.desktop` for KDE. Consolidates the current hardcoded `exec-once` lines in hyprland/functional.nix.

- [x] **Declarative idle/lock/sleep timeouts** — Add `customConfig.desktop.idle.lockTimeout` and `customConfig.desktop.idle.sleepTimeout` (in seconds). For Hyprland: feed into swayidle config. For KDE: feed into plasma-manager DPMS settings.

- [x] **Declarative monitor config (position + orientation) for XFCE** — Hyprland already
  consumes `customConfig.desktop.monitors`; this taught the **XFCE** session to apply the same
  layout (scope: XFCE only — KDE/Hyprland already fine). New `modules/home-manager/xfce/
  monitors.nix` resolves each monitor to its current X11 connector by **EDID** at login and
  applies position + orientation via xrandr (scale dropped; overlap from a fractionally-scaled
  primary corrected). Added optional `monitors.*.edid` (EDID substring) used only by XFCE,
  because X11 (NVIDIA) and Wayland report different connector names for the same port — so
  `identifier` (connector) drives Hyprland while `edid` drives XFCE. Also: portrait monitors get
  a vertical wallpaper, and the Win7 taskbar is cloned to every monitor (tray/volume on primary
  only). Verified on gaming-pc (XFCE live + Hyprland via hyprctl). *(committed on
  feat/xfce-windows7; desc: matching was tried but is unreliable in this Hyprland build, hence
  the connector-name + edid split.)* blaney-pc: still needs his real connector names + edids when
  his XFCE rollout is tested on-target.

- [ ] **X11: Start-menu / KWin "Restart" needs two clicks** — On Plasma X11 (and XFCE) clicking
  Start → Restart (or the KWin/logout power-menu Restart) does nothing on the first click; a
  second click works. Emerged on X11. Investigate the logout/shutdown path — `ksmserver` /
  `org.kde.LogoutPrompt` / `org.kde.Shutdown` DBus + journal on first-vs-second click (likely a
  first-invocation focus/grab or session-manager init race). Reproduce on gaming-pc Plasma X11.

- [ ] **distrobox for non-NixOS programs** — Add `customConfig.programs.distrobox.enable`. Enables running Arch/Ubuntu containers for software that resists NixOS packaging. Small scope.

- [ ] **Windows VM (QEMU/KVM)** — Enable `libvirtd` + `virt-manager` via a `customConfig.profiles.virtualization.enable` option. Includes UEFI (OVMF) support for Windows 11.

- [ ] **Winboat (Windows translation layer)** — Winboat is a newer Windows app translation layer for Linux. Needs research: check nixpkgs availability, or package it. Add to gaming profile or as a standalone option once viability is confirmed.

- [ ] **WSL2 dev shells guide** — Not a NixOS config change. Create `scripts/wsl2-setup.md` documenting: install Nix on WSL2 Ubuntu, run dev shells with `nix develop`, set up `usbipd-win` on Windows + `usbip` in WSL2 for USB passthrough (needed for embedded-linux and fpga-dev shells).

---

## XFCE (X11) + Windows 7 Theme

> New X11 desktop added as a coexisting login-session choice (rock-solid on NVIDIA;
> xfwm4/xfce4-panel make it a well-shaped Win7 canvas). Base env + a separate `windows7`
> theme, following the KDE/Hyprland functional-vs-theme paradigm. Iterated in `vm-sandbox`.
> Branch: `feat/xfce-windows7`. Full plan: staged M1–M5. Sandbox-only until M4 passes.
> Settled: vendor B00merang `Windows-7` (GTK+xfwm4) + reuse aero icons/cursors/sounds;
> toggleable `homeManager.themes.xfceOverride` (off = seed-once, on = rebuild-enforced).

- [ ] **M1 — base XFCE session boots** — `"xfce"` in `desktop.environments` enum;
  `modules/nixos/desktop/xfce.nix` (xserver + desktopManager.xfce + gtk portal + plugins);
  register in `desktop/default.nix`; `none`-path portal branch in `display-manager.nix`;
  sandbox wiring (`environments += "xfce"`, `defaultSession = mkForce "xfce"`). *(eval clean
  all 11 hosts; `xfce.desktop` xsession registers — needs in-person `testvm sandbox --clean`
  to confirm autologin lands in a working XFCE desktop)*
- [ ] **M2 — declarative xfconf plumbing** — `homeManager.themes.xfce` enum + `xfceOverride`
  option; `modules/home-manager/xfce/{default,functional}.nix` (reused `mkDesktopEntry`
  autostart + `mkDefault` xfconf seed); register in `home-manager/default.nix`. Go/no-go
  gate for the xfconf seed approach.
- [x] **M3 — Win7 visuals (xfwm4 + GTK + icons + cursor)** — `modules/nixos/themes/windows7-xfce/`
  (GTKAero GTK/xfwm4+icons derivation + aero-drop cursor derivation + XFCE-gated overlay,
  Segoe UI fonts installed without changing the system default);
  `modules/home-manager/themes/windows7-xfce/{default,theme,assets,xfconf}.nix`; register in
  `themes/default.nix`. **Switched B00merang→GTKAero** (B00merang's GTK3 CSS is pre-3.20 and
  renders stock on GTK 3.24; GTKAero is modern + bundles the Win7 Aero icon theme, so icons
  are done here, not deferred). Also fixed Ly to allow X11 sessions (`x_cmd` was hardcoded
  `/bin/false`). Verified natively on gaming-pc (widgets, icons, titlebars, font, cursor).
- [x] **M4 — panel/Start-menu + sounds + tray** — DONE. `panel.nix`: bottom taskbar
  (whiskermenu Start orb from SevenStart sprite cropped+trimmed 54x54→38x38, grouped window
  buttons, systray, xfce4-pulseaudio-plugin volume control, two-line clock, show-desktop);
  `keybindings.nix`: Super-tap → Start via xcape→Ctrl+Esc; `wallpaper.nix`: per-monitor via
  xrandr+xfconf login script; `sounds.nix` + `windows7-xfce-sounds` derivation: 'Windows 7'
  libcanberra theme (ORelio Faithful wavs, pinned; personal-use), login jingle self-unmutes
  by PID. Verified natively on gaming-pc. Notes: use full logout/login to test (not
  `xfce4-panel -r`, which deletes plugin rc); `xfceOverride` wipe covers `xfce-perchannel-xml/`
  AND `panel/`; on gaming-pc the default sink must be a proper FL/FR sink (jamesdsp_sink) —
  raw `pro-output-N` are unpositioned AUX and stereo players can't route to them; WirePlumber
  had `mute=yes` saved for the `paplay` app name (why the jingle was silent for so long).
- [ ] **M5 — fidelity + reproducibility pass** — refine `windows7-xfce/*` + `colors.nix`;
  confirm `xfceOverride` re-asserts theme on rebuild; side-by-side vs KDE aerotheme. Then
  revert sandbox `defaultSession` and consider real-host rollout.

### M6 — taskbar/tray polish + declarative options (post-M4 requests)

- [x] **Sounds: follow the last-set sink + volume** — Confirmed working. The login jingle plays
  via `paplay` (→ the last-set **default sink**) and sets the *stream-input* volume to `100%`,
  which is 100% **of the sink's current level** (sink-input volume is relative), so it plays at
  the user's last-set volume on the last-set sink. The only remaining "force" is the unmute
  (`set-sink-input-mute 0`), which just works around WirePlumber restoring `mute=yes` on the
  `paplay` app name — not a volume/sink override. Event sounds already follow the default sink.
- [x] **Tray: volume icon size + placement** — Shrunk panel `icon-size` 36→configurable 28
  (`xfcePanel.iconSize`); volume moved to the LEFT of the systray (which holds the network
  applet). Verified on gaming-pc.
- [x] **Declarative XFCE taskbar options (per-host, like KDE)** — Added
  `customConfig.homeManager.themes.xfcePanel.{pinnedApps,trayApplets,iconSize}`; `panel.nix`
  generates icon-only launcher plugins + their `.desktop` files + tray-applet autostarts from
  the options (open windows still show with labels in the tasklist). gaming-pc uses the rich
  blaney-mirroring set; Librewolf uses the Win7 Aero `internet-web-browser` (IE) icon.
- [x] **System tray applets (network/bluetooth/power/clipboard)** — `trayApplets` enum +
  autostarts (nm-applet, blueman, xfce4-power-manager, xfce4-clipman). Note: nm-applet only
  lists WiFi where a radio exists (gaming-pc is wired-only, so no WiFi menu there — works on
  hosts with a wireless card). Notifications are handled by xfce4-notifyd (already installed).
- [x] **Match blaney-pc's KDE pins on its XFCE** — Enabled `"xfce"` + `themes.xfce = "windows7"`
  on blaney-pc and set `xfcePanel.pinnedApps`/`trayApplets` mirroring its KDE set (kitty, Settings,
  Thunar, Chromium, Lutris, Heroic, Steam, Discord, Spotify, System Monitor, galculator,
  Polychromatic, input-remapper, OpenRGB, xpad-notes; tray network/bluetooth/power/clipboard).
  Eval-clean all hosts. *(PR open — needs on-target test on blaney: pick "Xfce Session" at Ly,
  confirm taskbar/icons + file-open defaults. NOTE the gaming-pc caveat below applies to blaney
  too — enabling XFCE there will likely break its KDE **Wayland**; blaney's KDE is X11-safe.)*

### M7 — XFCE session polish (startup/screensaver/lock/app theming)

- [x] **Spotify won't launch (taskbar + search)** — Real root cause: `NIXOS_OZONE_WL=1` is set
  globally (hyprland.nix) and leaks into the X11 XFCE session; Spotify's wrapper does
  `if NIXOS_OZONE_WL==1: unset DISPLAY`, so it can't reach X11. Fix: `xfce.nix` resets it via
  `services.xserver.displayManager.sessionCommands = "export NIXOS_OZONE_WL=0"` (X11-session
  scoped) — fixes both the taskbar launcher and Start-menu search, and any other Electron app.
  Taskbar Spotify launcher also carries `env NIXOS_OZONE_WL=0` as belt-and-suspenders. Verify
  on gaming-pc.

- [ ] **Startup apps (declarative)** — Wire per-host XFCE startup apps. The shared
  `customConfig.desktop.autostart` (command/desktops) is already consumed by
  `modules/home-manager/xfce/functional.nix` (filters `desktops` for `"xfce"`) → verify it
  works end-to-end and/or surface a cleaner per-host list. The tray applets + wallpaper/sound
  scripts already use the autostart mechanism.
- [x] **Screensaver: match the Ly ASCII-gif** — Done via **xscreensaver** (not xfce4-screensaver,
  whose saver engine returns NULL for every theme on NixOS — garcon theme discovery is broken, even
  its own built-ins never render). `windows7-xfce/screensaver.nix` ships a stdlib-Python `.dur`
  player that replays the host's exact Ly animation (resolved from `displayManager.ly.animationFile`,
  same fallback as `ly-century-series-theme.nix`), embedded via `xterm -into $XSCREENSAVER_WINDOW`
  and sized per-monitor. xfce4-screensaver is disabled (autostart override) and DPMS handed to
  xscreensaver. **Requires setuid `xscreensaver-auth` wrapper + PAM service** (in `desktop/xfce.nix`,
  gated on the windows7 theme) or unlock fails with "Password initialization failed". Verified on
  gaming-pc: animation renders on both monitors, locks + unlocks.
- [x] **Screen lock + display-off timeouts** — Consumes `customConfig.desktop.idle`
  (`screensaverTimeout`/`lockTimeout`/`sleepTimeout`) in XFCE. Now owned by **xscreensaver**
  (`screensaver.nix`): saver at `screensaverTimeout`, lock at `lockTimeout`, DPMS off at
  `sleepTimeout`. xfce4-power-manager DPMS is disabled in `idle.nix` (xscreensaver clobbers
  `xset` DPMS on activate, so they must not both manage it). gaming-pc: 15/20/30 min.
- [x] **Thunar toolbar overlap bug** — Cause: the GTKAero theme's bundled `thunar.css` is tuned
  for pre-4.20 Thunar (hardcoded `entry { height:16px !important }`, negative toolbar margins,
  magic offsets); Thunar 4.20's redesigned toolbar made those overlap the command row. Fix:
  `windows7-xfce-gtk.nix` drops the `@import "thunar.css"` (Thunar now uses the normal
  Win7-themed widgets) + appends a sane toolbar-entry height. Verified on gaming-pc. (Follow-up
  if wanted: re-add just the Win7 breadcrumb/path-bar styling adapted for 4.20.)
- [x] **App-theming audit (is everything Win7?)** — Made XFCE standalone (self-sufficient without
  KDE) + closed icon gaps. `xfce.nix` now installs the categories XFCE's default suite omits:
  `xarchiver` (+`thunar-archive-plugin` for right-click extract), `xreader` (PDF), `galculator`,
  `mpv`, `xpad` (sticky notes) — all GTK3 so they inherit the Win7 theme. `windows7-xfce-gtk.nix`
  aliases app-specific `org.xfce.*`/`xarchiver`/`galculator`/`mpv` Icon= names to the Aero
  standard icons the theme ships (Start menu / taskbar / titlebar now Aero, not stock). Verified
  on gaming-pc (apps open themed; mime scoping below). *(icon-in-Start-menu visual spot-check
  still worth a glance)*
- [x] **XFCE default-app associations** — Opening a file in an XFCE session launches the themed
  apps (Thunar/Mousepad/Ristretto/Parole/Xreader/xarchiver) via `windows7-xfce/mimeapps.nix` →
  `~/.config/xfce-mimeapps.list` (read only when `XDG_CURRENT_DESKTOP=XFCE`, so KDE/Hyprland
  associations are untouched; unlisted types fall through to the host default set). Verified on
  gaming-pc: XFCE→themed apps, KDE→Okular/Gwenview/Dolphin/Kate (zero leakage).

- [ ] **KNOWN ISSUE — enabling XFCE breaks KDE *Wayland* on NVIDIA hosts** — Adding `"xfce"` to
  `environments` forces `services.xserver.enable` system-wide, which breaks the KDE Plasma
  **Wayland** session on gaming-pc's NVIDIA-open + unused-AMD-iGPU box (kwin_wayland: `Atomic
  modeset test failed! Permission denied` / `Failed to find a working output layer configuration`
  → white cursor then black). **Hyprland (Wayland) and Plasma X11 both work.** Confirmed by
  branch-vs-`main` rebuild (main = no XFCE = Wayland works). **Decision (2026-07-27): keep XFCE,
  use the Plasma (X11) session for KDE on gaming-pc.** Likely real root cause is the NVIDIA
  **open** kernel module (gaming-pc is the only host on `open = true`; blaney + all others use
  proprietary — so blaney probably won't hit this). Optional future lever to reclaim KDE Wayland:
  flip gaming-pc to `hardware.nvidia.open = false` (proprietary), rebuild+reboot, verify KDE
  Wayland works + Plymouth splash still renders + Hyprland fine — one-line, reversible,
  gaming-pc-only. See memory `xfce-breaks-kde-wayland-gaming-pc`.

- [ ] **Test xfceOverride re-assertion (before PR)** — Verify `homeManager.themes.xfceOverride`
  behaves: ON = rebuild wipes `~/.config/xfce4/{xfconf/xfce-perchannel-xml,panel}` before
  linkGeneration so the declared theme/pins are re-asserted (runtime tweaks discarded); OFF =
  runtime tweaks persist. Test on gaming-pc: move/remove a panel launcher, rebuild, confirm ON
  reverts it and OFF keeps it. Part of M5; do before opening the PR. (Related: flip xfceOverride
  OFF on gaming-pc/vm-sandbox for daily use once satisfied.)

- [ ] **Theme the xscreensaver unlock dialog like Windows 7** — The XFCE lock uses xscreensaver's
  built-in password dialog (currently dark aviation colors in `~/.xscreensaver`). Make it Win7-ish
  within xscreensaver's limited theming — the `passwd.*` / dialog X-resources (foreground,
  background, borderColor, font, `passwd.heading`/logo, `passwd.thermometer.*`). Aim for an Aero
  light-blue/white palette + Segoe UI + a Win7 logo. Pixel-perfect Win7 isn't achievable with
  xscreensaver's dialog — get as close as the resource set allows. (User recalls a Win7-styled
  lock previously and wants that look back.)

---

## SDDM

- [ ] **SDDM: per-orientation theme layout for vertical monitors** — The sddm-astronaut theme is shared across all monitors but vertical/portrait monitors need layout adjustments. Goals: different wallpaper/background per monitor orientation, repositioned clock and login prompt (centered vertically for portrait), potentially larger font for the narrow portrait width. Requires either forking/patching the sddm-astronaut theme QML or finding a theme that supports per-screen layout overrides. Scope: research SDDM multi-screen QML theming, then implement as a `customConfig.desktop.displayManager.sddm.portraitLayout` option.

---

## KDE Themes

- [ ] **aerothemeplasma: upstream as standalone flake** — The Windows 7 / Aero theme derivation in `modules/home-manager/themes/aerothemeplasma/` is a custom Nix package. Goal: publish it as a standalone Nix flake that others can use. Steps: (1) Check upstream activity at gitgud.io/aeroshell/atp/aerothemeplasma — it has recent commits, so coordinate rather than fork. (2) Determine if a PR to add a `flake.nix` to upstream is appropriate, or if a separate repo that wraps it as a flake is better. (3) Once published, replace the inline derivation in this config with a flake input. Medium scope; requires upstream communication.

---

## KDE

- [x] **KDE bigsur: auto light/dark with time of day** — Use KDE Plasma 6's built-in automatic dark/light switching (sunset/sunrise). Configure via plasma-manager. First verify whether the bigsur nixpkgs theme includes both light and dark variants.

- [ ] **KDE captive portal auto-open** — Public wifi landing pages don't automatically open in KDE. Enable NetworkManager's connectivity check (`networking.networkmanager.connectionConfig`) and/or ensure `plasma-nm` captive portal detection is active so the browser launches automatically when a captive portal is detected.

---

## Hyprland

- [x] **Hyprland lid close lock bug** — *(PR [#25](https://github.com/landonreekstin/nixos-config/pull/25))* Replaced swaylock+swayidle with hyprlock+hypridle. Root cause of lock crash: hyprlock's `screenshot` background path crashed when launched via `before_sleep_cmd` because the compositor was already tearing down outputs. Fixed by switching to a static wallpaper. Also set `no_fade_in = true` so input is immediately ready on manual lock.

- [ ] **Refactor exec shortcuts to customConfig variables** — Add `customConfig.hyprland.apps.terminal`, `.editor`, `.browser`, `.music`, `.fileManager` with sane defaults (kitty, neovim, librewolf, spotify, yazi). Keybindings reference these instead of hardcoded commands.

- [x] **All keybind functionality** — Audit and fill out missing keybindings in hyprland/functional.nix: window focus/move/resize (vim keys), workspace management, screenshot (grim+slurp), clipboard (cliphist), screen lock (swaylock), brightness, volume.

- [x] **Power/logout menu (wlogout)** — Add `wlogout` with a keybind (e.g. `super+escape`). Style it to match the active Hyprland theme.

- [ ] **Neovim full managed config** — Create a Home Manager neovim module. Goals: LSP (nixd, lua_ls, pyright, clangd), Treesitter, telescope, which-key, oil.nvim (file manager), lualine, lazy.nvim plugin manager. Full lua config managed declaratively. Enable via `customConfig.programs.neovim.enable`.

- [x] **Keyboard shortcut cheatsheet (Super+/)** — Bind `super+/` to open a wofi popup listing all current Hyprland keybindings. True "show while holding mod" behavior is complex; a popup is the practical v1.

- [ ] **Enable/disable monitors keybind** — Bind a key to `hyprctl dispatch dpms toggle` for toggling monitor power. Useful for multi-monitor setups.

- [ ] **Games in true fullscreen (windowrules)** — Add Hyprland `windowrule` entries to force fullscreen for Steam game windows. Prevents Wayland compositor overhead during gameplay.

- [ ] **Workspace arrange preset** — Shell script using `hyprctl` to open a defined set of apps into specific workspaces (e.g. workspace 1: terminal + browser, workspace 2: editor, workspace 3: music). Invocable by keybind or autostart.


---

## Waybar

- [x] **Century Series: battery percentage gradient** — The existing Waybar battery module changes text/icon at low/AC states. Extend it to show a continuous color gradient as percentage changes: green (100%) → yellow (~50%) → orange (~25%) → red (~10%). Implement via a custom script or `format-icons` array that covers enough steps to appear smooth. Apply to any host with a battery (gated on `customConfig.hardware.isLaptop` or battery presence detection).

- [ ] **Dynamic audio icons by output device** — Replace the static pulseaudio module with a custom script that detects the current PipeWire sink (headphones vs. speakers vs. USB DAC) and shows a matching icon.

- [x] **Gammastep toggle module** — Add a Waybar custom module that toggles gammastep on/off (or cycles through off → warm → very warm presets). Click to toggle, scroll to adjust temperature.

- [x] **Waybar screen + keyboard brightness modules** — Add Waybar modules showing current screen brightness (via `brightnessctl`) and keyboard backlight brightness (via `asusctl`), each with appropriate icons. Clicking or scrolling should adjust the value. Scope to hosts with Hyprland (gaming-pc, asus-laptop).

- [x] **Waybar network: replace LINK with networkmanager_dmenu** — The current network module click action only shows the active adapter. Replace with `networkmanager_dmenu` so clicking opens a rofi-based wifi/wired picker for connecting to and managing networks. Theme the dmenu instance to match the Century Series aesthetic (phosphor green on black, monospace, MFD borders).

---

## Librewolf

- [x] **Librewolf profile preset** — Add a named preset to `customConfig.programs.firefox` (e.g. `preset = "privacy"`). The preset applies a curated set of extensions (uBlock Origin, SponsorBlock, etc.), bookmarks, and `userSettings` (privacy hardening flags) from gaming-pc's current Librewolf setup. Uses the existing Firefox Home Manager module.

---

## Century Series Theme (Hyprland)

> **Note:** Substantial work already exists in the `dev-century-series-theme` branch. Review and merge/rebase that branch before starting any of these tasks rather than starting from scratch.

- [ ] **Theme rofi to look like MFD** — Style rofi-wayland with CSS to match the Century Series aesthetic: phosphor green on instrument-panel black, monospace font, MFD-style borders. Replace wofi after the rofi migration above.

- [x] **Century Series rofi: matched text invisible when selected** — When an item is selected in rofi, the highlighted matching characters are the same color as the selection box background, making them invisible. Fix the rofi CSS theme so matched/highlighted characters use a contrasting color (e.g. bright amber or white) within the selected row.

- [x] **Theme swaylock** — Configure swaylock to match Century Series: dark background, amber/green text, MFD-style layout.

- [x] **Theme apps (btop, yazi)** — Apply Century Series color scheme to btop (custom theme file) and yazi (theme.toml). Phosphor green on black.

- [x] **Bash prompt color/style via customConfig** — Add `customConfig.homeManager.themes.bashPrompt` (color, style). Century Series default: amber PS1 with hostname and git branch. Override-able per host.

- [x] **QT and GTK themes** — GTK set to Adwaita-dark with Papirus-Dark icons. QT theming intentionally omitted: hosts with both KDE and Hyprland use KDE's Plasma theme for QT apps, and Hyprland-focused apps (kitty, wofi, waybar, yazi) are GTK or terminal-based.

- [ ] **Audio output selection widget** — A rofi menu listing available PipeWire sinks, selecting one switches the default output. Invocable from Waybar or keybind.

- [x] **Engine power switch (wlogout styled)** — Style wlogout to look like aviation engine controls: shutdown = engine cut, restart = engine restart, logout = eject. Custom icons and CSS matching Century Series.

- [ ] **Additional wallpapers** — Curate a set of aviation/cockpit wallpapers for Century Series. Add to `customConfig.homeManager.themes.wallpaper` options or a wallpaper rotation list.

---

## Secrets Management (sops-nix)

> Core infrastructure is on `main`. Tasks here are sequenced — the age key collection task (first) unblocks most of the rest.

### Prerequisites

- [x] **Collect age keys for primary hosts** — Run `cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age` and replace placeholders in `.sops.yaml`. Done: gaming-pc, optiplex, optiplex-nas. Remaining hosts (blaney-pc, justus-pc, asus-m15, atl-mini-pc) are off-network and working fine without sops — collect if/when needed.

### Declarative User Passwords (High Value)

- [ ] **User passwords via sops** — Use `customConfig.user.sopsPasswordEnable = true` and create encrypted `secrets/<host>.yaml` with `user-password-hash` key. Infrastructure complete: shared option wires `hashedPasswordFile` and sets `mutableUsers = false`. *(Done: gaming-pc, optiplex, optiplex-nas. Off-network hosts deferred.)*

### Service Secrets

- [x] **media-linker API keys → sops (optiplex-nas)** — The media-linker service reads `JELLYSEERR_API_KEY`, `RADARR_API_KEY`, and `SONARR_API_KEY` from `/root/secrets/media-linker.env`. Migrate to a sops secret file: encrypt the env file as `secrets/optiplex-nas.yaml`, expose it via `sops.secrets.media-linker-env` with `owner = "root"`, and update `customConfig.homelab.mediaLinker.envFile` (currently set in common-options.nix) to point to `config.sops.secrets.media-linker-env.path`. Removes the manual file creation step from optiplex-nas setup.

- [ ] **atl-mini-pc WireGuard server private key → sops** — The WireGuard server config on atl-mini-pc references `/etc/nixos/secrets/wireguard/server-privatekey` (currently disabled). Before enabling, migrate to sops: add a `wireguard-server-private-key` secret to `secrets/atl-mini-pc.yaml`, update `customConfig.services.wireguard.server.privateKeyFile` to use `config.sops.secrets.wireguard-server-private-key.path`. Mirror the pattern already used for the asus-laptop client key.

### Install Script Integration

- [ ] **install-new-host.sh: sops bootstrapping** — When a new host is installed, its SSH host key is generated but its age key isn't yet in `.sops.yaml`. Add a post-install step (or a separate `scripts/add-host-key.sh`) that: (1) reads the new host's SSH ed25519 public key, (2) converts it to age via `ssh-to-age`, (3) adds it to `.sops.yaml` under the right host anchor and creation rules, (4) re-encrypts any `secrets/common.yaml` to include the new host. This must run on the admin machine (gaming-pc) since it needs the age admin key.

### Not Suitable for sops (Reference)

- **optiplex-nas LUKS key** — The LUKS key at `/root/secrets/private_luks.key` is needed at initrd time, before sops-nix activates. Keep using `boot.initrd.secrets` as-is. If reproducible initrd secrets are ever needed, evaluate `systemd-cryptenroll` with a TPM2 or FIDO2 key instead.
- **WireGuard peer public keys / endpoint IPs** — Public keys are not secret by design. The endpoint IP `68.184.198.204:51822` is semi-sensitive but hardcoding it in the Nix config is acceptable; it's not a credential.
