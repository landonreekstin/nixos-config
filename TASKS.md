# NixOS Config Task List

Tasks are grouped by category. Reorder within a group to set priority.
Format: `- [ ] **Title** — description`

**Workflow:** Before committing any change, run `rebuild-test` locally to verify it activates cleanly. Only commit and push once it passes.

---

## System / Core

- [ ] **Update notification: sync & rebuild action button** — Extend `modules/home-manager/services/update-notification.nix` to include a dunst action button labeled "Update & Rebuild" that runs `sync && rebuild` in a terminal (or background with follow-up notification). Add a second notification on completion indicating success or failure. KDE: use `kdialog` or a `.desktop` action instead of dunstify. Gate behind the existing `cfg.enable` option.

- [ ] **Branch maintenance workflow** — Define cleanup guidelines and optionally a GitHub Actions workflow for recurring branch hygiene. Guidelines for Claude to follow when asked to do a branch audit: (1) list all remote branches with last-commit date, (2) for each stale branch (no commits in >30 days), check if its diff is already present in main via `git log --cherry-pick --left-right`, (3) categorize as: *merged/obsolete* (all commits present in main — safe to delete), *superseded* (changes exist but reimplemented differently — needs human confirm), *in-progress* (diverged, unique work — keep), (4) present a summary and wait for explicit approval before deleting anything. GitHub Actions stretch goal: a scheduled workflow (monthly) that opens a GitHub Issue listing stale branches with their categorization, so the audit is triggered automatically and the conversation happens in the issue.

- [ ] **Custom installer USB image** — Build a custom NixOS ISO using `nixos-generators` or a custom `nixos-rebuild` ISO configuration. Goals: pre-bake the flake repo, SSH keys for initial access, and the `post-install` script so a fresh machine can be bootstrapped from USB without internet. Scope: add a `nix build .#iso` output to `flake.nix` using `nixos-generators` flake input and a new `hosts/installer/` configuration. The installer config should include the current SSH authorized keys, the flake itself, and a minimal desktop for the install wizard. Extends `scripts/install-new-host.sh`.

- [ ] **Improve sync command with interactive conflict resolution** — The current `sync` command in `modules/nixos/common/commands.nix` (lines ~121–180) auto-stashes on conflict without prompting. Enhance it to: (1) detect local uncommitted changes and ask the user whether to stash, commit to a new branch, or abort; (2) perform the pull/merge; (3) automatically unstash or offer to unstash if a stash was created. Also add a prompt before deleting any local changes that would be clobbered. Keep non-interactive behavior for beta-tester branch switching logic unchanged.

- [ ] **README: document sync/rebuild/update commands with CI/CD framing** — Add a dedicated section to `README.md` explaining the automated `sync`, `rebuild`, `update`, and `upgrade` commands defined in `modules/nixos/common/commands.nix`. Frame them as a declarative CI/CD pipeline: weekly automated flake updates (optiplex-nas), beta-tester host auto-tracking (`update/*` branch), binary cache push on rebuild, multi-host eval in GitHub Actions. Context: highlights production NixOS infrastructure experience relevant to Anduril Embedded NixOS Engineer role (EW team; see `~/cpp_practice/CLAUDE.md` for interview context). Also cross-reference the FPGA/kernel/embedded-linux dev shells.

- [ ] **README: highlight Anduril-aligned config features** — Add a section or callouts in `README.md` that surface the parts of this config most relevant to the Anduril Embedded NixOS Engineer (EW team) role. Key areas to emphasize: (1) multi-host CI/CD pipeline with automated flake updates, PR gating, and binary cache; (2) custom installer image / NixOS bringup workflow (`scripts/install-new-host.sh`); (3) development shells for kernel, FPGA (iCE40), embedded Linux cross-compilation, and Game Boy (`nix develop .#*`); (4) SOPS/age secrets infrastructure for production secret management; (5) custom NixOS modules and option system (`customConfig`); (6) homelab deployment (Jellyfin, arr stack, WireGuard VPN). Context: Anduril EW team is seeking NixOS engineers for build/deployment infrastructure, hardware bringup, and software supply chain — see `~/cpp_practice/CLAUDE.md`.

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

- [ ] **distrobox for non-NixOS programs** — Add `customConfig.programs.distrobox.enable`. Enables running Arch/Ubuntu containers for software that resists NixOS packaging. Small scope.

- [ ] **Windows VM (QEMU/KVM)** — Enable `libvirtd` + `virt-manager` via a `customConfig.profiles.virtualization.enable` option. Includes UEFI (OVMF) support for Windows 11.

- [ ] **Winboat (Windows translation layer)** — Winboat is a newer Windows app translation layer for Linux. Needs research: check nixpkgs availability, or package it. Add to gaming profile or as a standalone option once viability is confirmed.

- [ ] **WSL2 dev shells guide** — Not a NixOS config change. Create `scripts/wsl2-setup.md` documenting: install Nix on WSL2 Ubuntu, run dev shells with `nix develop`, set up `usbipd-win` on Windows + `usbip` in WSL2 for USB passthrough (needed for embedded-linux and fpga-dev shells).

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

- [ ] **Fix: Signal notifications render as black bar in Hyprland** — Signal (Electron/XWayland app) notifications appear as a full-height black vertical bar on the right side of the screen instead of a normal notification popup. Likely cause: Signal's native notification window is positioned off-screen or unsized correctly under XWayland, or dunst is not intercepting it and the raw X11 notification window is rendering unconstrained. Debug steps: (1) check `hyprctl clients` when notification appears to see window class/size; (2) add a `windowrulev2` to float+position Signal's notification class; (3) alternatively, ensure Signal uses the system notification daemon (dunst) via `--use-tray-icon` or D-Bus inhibit flag. File: `modules/home-manager/hyprland/functional.nix` for windowrule; `modules/home-manager/themes/century-series/dunst.nix` for dunst config.

- [ ] **Terminal border: red/yellow glow when Claude is waiting** — Use Claude Code hooks (`~/.claude/settings.json`) to change the active terminal window's Hyprland border color via `hyprctl`. Behavior: (a) **Yellow** border when Claude has finished generating and is waiting for the next prompt (hook: `Stop`); (b) **Red** border when Claude is waiting for the user to approve/deny a tool permission (hook: `PreToolUse`). Border reverts to normal Century Series amber on next user input. Implementation: hooks run `hyprctl keyword general:col.active_border <color>` on the active window class. Century Series amber = `#ff9e3b`, yellow = `#ffdd57`, red = `#ff3838` (already defined in `modules/home-manager/themes/century-series/colors.nix`).

- [x] **Hyprland lid close lock bug** — *(PR [#25](https://github.com/landonreekstin/nixos-config/pull/25))* Replaced swaylock+swayidle with hyprlock+hypridle. Root cause of lock crash: hyprlock's `screenshot` background path crashed when launched via `before_sleep_cmd` because the compositor was already tearing down outputs. Fixed by switching to a static wallpaper. Also set `no_fade_in = true` so input is immediately ready on manual lock.

- [ ] **Refactor exec shortcuts to customConfig variables** — Add `customConfig.hyprland.apps.terminal`, `.editor`, `.browser`, `.music`, `.fileManager` with sane defaults (kitty, neovim, librewolf, spotify, yazi). Keybindings reference these instead of hardcoded commands.

- [x] **All keybind functionality** — Audit and fill out missing keybindings in hyprland/functional.nix: window focus/move/resize (vim keys), workspace management, screenshot (grim+slurp), clipboard (cliphist), screen lock (swaylock), brightness, volume.

- [x] **Power/logout menu (wlogout)** — Add `wlogout` with a keybind (e.g. `super+escape`). Style it to match the active Hyprland theme.

- [ ] **Neovim full managed config** — Create a Home Manager neovim module. Goals: LSP (nixd, lua_ls, pyright, clangd), Treesitter, telescope, which-key, oil.nvim (file manager), lualine, lazy.nvim plugin manager. Full lua config managed declaratively. Enable via `customConfig.programs.neovim.enable`.

- [x] **Keyboard shortcut cheatsheet (Super+/)** — Bind `super+/` to open a wofi popup listing all current Hyprland keybindings. True "show while holding mod" behavior is complex; a popup is the practical v1.

- [ ] **Enable/disable monitors keybind** — Bind a key to `hyprctl dispatch dpms toggle` for toggling monitor power. Useful for multi-monitor setups.

- [ ] **Games in true fullscreen (windowrules)** — Add Hyprland `windowrule` entries to force fullscreen for Steam game windows. Prevents Wayland compositor overhead during gameplay.

- [ ] **Minimize windows in Hyprland with glowing cockpit launcher buttons** — Hyprland has no native minimize, but windows can be sent to a named special workspace (e.g. `special:minimized`) to hide them. Goals: (1) keybind to send/recall a window from `special:minimized` (extend existing special workspace pattern in `hyprland/functional.nix` — see existing `special:ckb`); (2) Waybar launcher buttons in `waybar/functional.nix` show open/minimized app state with per-app glow colors (statically assigned in config — e.g. kitty=amber, librewolf=steel-blue, spotify=phosphor-green, matching Century Series palette in `colors.nix`); (3) if a minimized app is NOT in the static launcher list, dynamically append a temporary button icon using a custom Waybar script that queries `hyprctl clients | jq` for windows in `special:minimized`; (4) buttons appear as backlit illuminated cockpit panel buttons — active = full glow, minimized = dim pulse, inactive = off. Large scope; consider breaking into sub-tasks when implementing.

- [ ] **Hyprland session presets and session restore** — *(supersedes "Workspace arrange preset")* Two related features: (a) **Session Presets** — define named presets in `customConfig.hyprland.sessionPresets` (list of `{name, apps: [{command, workspace, monitor}]}`), activatable by keybind or Waybar widget; presets open apps into specified workspaces and monitors via `hyprctl dispatch exec` + `hyprctl dispatch movetoworkspacesilent`. (b) **Session Restore** — on logout/shutdown, serialize the current window list and workspaces (via `hyprctl clients -j` and `hyprctl workspaces -j`) to `~/.config/hypr/session.json`; on Hyprland startup, replay the session by re-launching stored apps on their last-known workspace/monitor. Implement restore as an `exec-once` script. Files: `hyprland/functional.nix`, `waybar/functional.nix`, new `scripts/hypr-session.sh`.


---

## Waybar

- [x] **Century Series: battery percentage gradient** — The existing Waybar battery module changes text/icon at low/AC states. Extend it to show a continuous color gradient as percentage changes: green (100%) → yellow (~50%) → orange (~25%) → red (~10%). Implement via a custom script or `format-icons` array that covers enough steps to appear smooth. Apply to any host with a battery (gated on `customConfig.hardware.isLaptop` or battery presence detection).

- [ ] **Dynamic audio icons by output device** — Replace the static pulseaudio module with a custom script that detects the current PipeWire sink (headphones vs. speakers vs. USB DAC) and shows a matching icon.

- [x] **Gammastep toggle module** — Add a Waybar custom module that toggles gammastep on/off (or cycles through off → warm → very warm presets). Click to toggle, scroll to adjust temperature.

- [x] **Waybar screen + keyboard brightness modules** — Add Waybar modules showing current screen brightness (via `brightnessctl`) and keyboard backlight brightness (via `asusctl`), each with appropriate icons. Clicking or scrolling should adjust the value. Scope to hosts with Hyprland (gaming-pc, asus-laptop).

- [x] **Waybar network: replace LINK with networkmanager_dmenu** — The current network module click action only shows the active adapter. Replace with `networkmanager_dmenu` so clicking opens a rofi-based wifi/wired picker for connecting to and managing networks. Theme the dmenu instance to match the Century Series aesthetic (phosphor green on black, monospace, MFD borders).

- [ ] **Audio: persist last PipeWire volume across reboots** — The system currently resets audio volume on login. Configure PipeWire/WirePlumber to restore the last-used volume level. WirePlumber (`services.pipewire.wireplumber.enable`) supports state persistence via `~/.local/state/wireplumber/` — verify it is enabled and not being reset. If volumes are still lost, check whether `services.pipewire.alsa.enable` or pulse emulation state is clobbering the level. Add `wireplumber` config if needed to set restore policy. No new `customConfig` option needed unless per-host override becomes necessary.

- [ ] **Waybar Bluetooth module + Century-series theme** — Add a `bluetooth` module to `waybar/functional.nix` (currently absent). Use the Waybar built-in `bluetooth` module type; on-click launches `blueman-manager` or a `bluetoothctl` rofi menu. Century-series theme in `themes/century-series/waybar.nix`: style with phosphor-green icons when connected, gunmetal when off, amber when pairing — matching the existing instrument panel aesthetic. Add `blueman` to system packages where Bluetooth is enabled (gate on `hardware.bluetooth.enable`).

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

- [ ] **Century-series wlogout: replace SVG engine controls with simple text+color icons** — The current `wlogout.nix` uses complex SVG cockpit-switch artwork with metallic gradients and screw-head details. Replace with simple colored text labels that match the MFD/instrument panel text aesthetic used elsewhere in the theme: monospace font, colored label on dark background, minimal border — consistent with rofi, dunst, and the Waybar instrument panel style. Suggested style: each button is a rectangular cell (like a Waybar module), with a short ALL-CAPS label (e.g. `SHUTDOWN`, `REBOOT`, `LOGOUT`, `LOCK`, `SUSPEND`) and a color accent border matching its severity (red=shutdown, amber=reboot, steel-blue=logout, green=lock). File: `modules/home-manager/themes/century-series/wlogout.nix`.

- [ ] **Century-series: CRT shutoff animation on window close / system shutdown** — Add a CRT-style power-off animation to the Century Series theme. For **window close**: configure a Hyprland animation in `themes/century-series/hyprland.nix` that shrinks the window vertically to a horizontal scanline then fades out (using Hyprland's custom bezier + animation system — see `animations` block). For **system shutdown**: create a short `wlogout`-triggered or `systemd` shutdown script that briefly runs a `hyprctl dispatch exec` fullscreen CRT-off effect (e.g. a minimal SDL/OpenGL overlay or a swaylock-like fullscreen black flash) before the system powers down. The window-close animation is lower scope and should be implemented first; the shutdown overlay is a stretch goal.

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
