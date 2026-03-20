# NixOS Config Task List

Tasks are grouped by category. Reorder within a group to set priority.
Format: `- [ ] **Title** — description`

**Workflow:** Before committing any change, run `rebuild-test` locally to verify it activates cleanly. Only commit and push once it passes.

---

## System / Core

- [x] **rebuild: -j flag + rebuild-test command** — Add `--max-jobs auto` to the rebuild script for parallel builds. Add a `rebuild-test` command alias that runs `nixos-rebuild test` (activates config without creating a boot entry, reverts on reboot).

- [x] **Gamemode polkit fix** — Two polkit auth windows appear when launching games. Cause: gamemode is trying to set the CPU governor but the polkit rule granting the `gamemode` group permission is missing. Add the polkit rule to the gaming profile so it happens silently.

- [x] **Plymouth boot splash** — Add Plymouth boot animation for hosts using systemd-boot. Scope: add a `customConfig.bootloader.plymouth` option with theme selection. Start with a clean minimal theme.

- [x] **Display manager "none": autostart first DE in list** — When `displayManager.type = "none"`, the current logic hardcodes Hyprland. Change it to launch whatever DE is first in `customConfig.desktop.environments` instead.

- [ ] **SDDM: suppress screensaver while media is playing** — The SDDM astronaut screensaver activates on idle even when video is playing. Add idle inhibit logic so the screensaver does not trigger while a media player has an active inhibitor (mpv, vlc, etc.). Implement via swayidle inhibit rules or a systemd-inhibit wrapper depending on DE.

- [x] **GitHub update notification**

- [ ] **Remove electron_39 → electron_40 alias** — Added in `modules/nixos/unstable-overlay.nix` as a workaround for a broken nixpkgs patch on `electron 39.8.2`. After any `flake update`, test removal by deleting the alias overlay and running `NIXPKGS_ALLOW_UNFREE=1 nix eval --impure .#nixosConfigurations.asus-laptop.config.system.build.toplevel.drvPath`. If eval passes, the upstream fix is in and the alias can be deleted.

- [ ] **Nix SOPS secrets management** — Add `sops-nix` as a flake input. Migrate secrets (WireGuard keys, passwords, API tokens) to encrypted SOPS files stored in the repo. Requires generating age keys per host. Significant scope — plan as a dedicated session.

- [x] **Encrypted DNS** — Add `customConfig.networking.encryptedDns.enable` backed by `services.dnscrypt-proxy2`. Include option for resolver selection (Cloudflare, Quad9, etc.).

---

## Hardware / Peripherals

- [ ] **Asus-m15: AirPods Max support (librepods)** — Add librepods as a flake input (it has a Nix flake). Enable as a systemd service on asus-m15 only, gated behind a `customConfig` option. Provides ANC control, battery status, and ear detection.

- [ ] **Asus-m15: Touchpad gestures in KDE** — Configure 3-finger swipe for virtual desktop switching and 4-finger swipe for app overview using KDE Plasma 6 native gesture support (no extra package needed). Configure declaratively via plasma-manager.

- [ ] **Logitech G305 Lightspeed support** — Enable `customConfig.hardware.peripherals.solaar = true` on gaming-pc. Optionally add `piper`/`libratbagd` for button remapping. Verify G305 is in solaar's supported device list.

- [ ] **Asus-laptop: keyboard brightness lower key not working** — The raise keyboard backlight key works (asusctl is functional) but the lower key does not. Likely a missing Hyprland keybind for the decrease action (`asusctl -k down` or equivalent). Add the missing bind in the asus-laptop Hyprland config alongside the existing raise bind.

- [x] **Global monitor configuration (customConfig.hardware.monitors)** — Add a `customConfig.hardware.monitors` option (list of monitor specs: name, resolution, refresh, position, orientation, scale). Default: single 1920x1080 horizontal monitor. All modules that need monitor info (Hyprland, SDDM, KDE) read from this one place instead of duplicating. Medium-large scope.

---

## Desktop — General (All DEs)

- [ ] **Default browser via customConfig** — Add `customConfig.programs.defaultBrowser` option. Feed it into `xdg.mimeApps.defaultApplications` for `text/html`, `x-scheme-handler/http`, `x-scheme-handler/https`, etc.

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

## KDE

- [x] **KDE bigsur: auto light/dark with time of day** — Use KDE Plasma 6's built-in automatic dark/light switching (sunset/sunrise). Configure via plasma-manager. First verify whether the bigsur nixpkgs theme includes both light and dark variants.

- [ ] **KDE captive portal auto-open** — Public wifi landing pages don't automatically open in KDE. Enable NetworkManager's connectivity check (`networking.networkmanager.connectionConfig`) and/or ensure `plasma-nm` captive portal detection is active so the browser launches automatically when a captive portal is detected.

---

## Hyprland

- [ ] **Refactor exec shortcuts to customConfig variables** — Add `customConfig.hyprland.apps.terminal`, `.editor`, `.browser`, `.music`, `.fileManager` with sane defaults (kitty, neovim, librewolf, spotify, yazi). Keybindings reference these instead of hardcoded commands.

- [ ] **All keybind functionality** — Audit and fill out missing keybindings in hyprland/functional.nix: window focus/move/resize (vim keys), workspace management, screenshot (grim+slurp), clipboard (cliphist), screen lock (swaylock), brightness, volume.

- [x] **Power/logout menu (wlogout)** — Add `wlogout` with a keybind (e.g. `super+escape`). Style it to match the active Hyprland theme.

- [ ] **Neovim full managed config** — Create a Home Manager neovim module. Goals: LSP (nixd, lua_ls, pyright, clangd), Treesitter, telescope, which-key, oil.nvim (file manager), lualine, lazy.nvim plugin manager. Full lua config managed declaratively. Enable via `customConfig.programs.neovim.enable`.

- [x] **Keyboard shortcut cheatsheet (Super+/)** — Bind `super+/` to open a wofi popup listing all current Hyprland keybindings. True "show while holding mod" behavior is complex; a popup is the practical v1.

- [ ] **Enable/disable monitors keybind** — Bind a key to `hyprctl dispatch dpms toggle` for toggling monitor power. Useful for multi-monitor setups.

- [ ] **Games in true fullscreen (windowrules)** — Add Hyprland `windowrule` entries to force fullscreen for Steam game windows. Prevents Wayland compositor overhead during gameplay.

- [ ] **Workspace arrange preset** — Shell script using `hyprctl` to open a defined set of apps into specific workspaces (e.g. workspace 1: terminal + browser, workspace 2: editor, workspace 3: music). Invocable by keybind or autostart.

- [ ] **Switch wofi to rofi-wayland** — `rofi-wayland` supports frecency sorting (most recently used apps first) which wofi lacks. Migrate launcher, run dialog, and any scripts currently using wofi.

---

## Waybar

- [ ] **Dynamic audio icons by output device** — Replace the static pulseaudio module with a custom script that detects the current PipeWire sink (headphones vs. speakers vs. USB DAC) and shows a matching icon.

- [ ] **Gammastep toggle module** — Add a Waybar custom module that toggles gammastep on/off (or cycles through off → warm → very warm presets). Click to toggle, scroll to adjust temperature.

- [x] **Waybar screen + keyboard brightness modules** — Add Waybar modules showing current screen brightness (via `brightnessctl`) and keyboard backlight brightness (via `asusctl`), each with appropriate icons. Clicking or scrolling should adjust the value. Scope to hosts with Hyprland (gaming-pc, asus-laptop).

- [x] **Waybar network: replace LINK with networkmanager_dmenu** — The current network module click action only shows the active adapter. Replace with `networkmanager_dmenu` so clicking opens a rofi-based wifi/wired picker for connecting to and managing networks. Theme the dmenu instance to match the Century Series aesthetic (phosphor green on black, monospace, MFD borders).

---

## Librewolf

- [ ] **Librewolf profile preset** — Add a named preset to `customConfig.programs.firefox` (e.g. `preset = "privacy"`). The preset applies a curated set of extensions (uBlock Origin, SponsorBlock, etc.), bookmarks, and `userSettings` (privacy hardening flags) from gaming-pc's current Librewolf setup. Uses the existing Firefox Home Manager module.

---

## Century Series Theme (Hyprland)

> **Note:** Substantial work already exists in the `dev-century-series-theme` branch. Review and merge/rebase that branch before starting any of these tasks rather than starting from scratch.

- [ ] **Theme rofi to look like MFD** — Style rofi-wayland with CSS to match the Century Series aesthetic: phosphor green on instrument-panel black, monospace font, MFD-style borders. Replace wofi after the rofi migration above.

- [ ] **Century Series rofi: matched text invisible when selected** — When an item is selected in rofi, the highlighted matching characters are the same color as the selection box background, making them invisible. Fix the rofi CSS theme so matched/highlighted characters use a contrasting color (e.g. bright amber or white) within the selected row.

- [x] **Theme swaylock** — Configure swaylock to match Century Series: dark background, amber/green text, MFD-style layout.

- [x] **Theme apps (btop, yazi)** — Apply Century Series color scheme to btop (custom theme file) and yazi (theme.toml). Phosphor green on black.

- [x] **Bash prompt color/style via customConfig** — Add `customConfig.homeManager.themes.bashPrompt` (color, style). Century Series default: amber PS1 with hostname and git branch. Override-able per host.

- [x] **QT and GTK themes** — GTK set to Adwaita-dark with Papirus-Dark icons. QT theming intentionally omitted: hosts with both KDE and Hyprland use KDE's Plasma theme for QT apps, and Hyprland-focused apps (kitty, wofi, waybar, yazi) are GTK or terminal-based.

- [ ] **Audio output selection widget** — A rofi menu listing available PipeWire sinks, selecting one switches the default output. Invocable from Waybar or keybind.

- [x] **Engine power switch (wlogout styled)** — Style wlogout to look like aviation engine controls: shutdown = engine cut, restart = engine restart, logout = eject. Custom icons and CSS matching Century Series.

- [ ] **Additional wallpapers** — Curate a set of aviation/cockpit wallpapers for Century Series. Add to `customConfig.homeManager.themes.wallpaper` options or a wallpaper rotation list.
