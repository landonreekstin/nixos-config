# nixos-config

A modular, multi-host NixOS flake managing 8 machines — development workstations, laptops, a homelab server, and machines for friends and family. Everything is declarative, version-controlled, and evaluated in CI on every push.

## Architecture

Configuration is driven by a custom option system (`customConfig`) defined in [`modules/nixos/common-options.nix`](modules/nixos/common-options.nix). Host configs set typed, validated options rather than raw NixOS attributes — this keeps host files small and pushes complexity into well-tested shared modules.

```
flake.nix
├── hosts/              # Per-host entry points (hardware + customConfig values)
├── modules/
│   ├── nixos/          # System modules (hardware, services, profiles, homelab)
│   └── home-manager/   # User modules (components, themes, programs)
└── pkgs/               # Custom derivations
```

## Development Shells

Four `nix develop` environments, each self-contained with toolchains and helper scripts:

### `#kernel-dev`

Full Linux kernel development environment with a QEMU guest workflow. Includes build tools (`gcc`, `make`, `flex`, `bison`, `pahole`), static analysis (`sparse`, `cppcheck`, `flawfinder`), profiling (`perf`, `trace-cmd`, `rt-tests`), and LLVM/Clang for cross-analysis. Custom scripts handle the full dev loop:

```
create-guest-image   # Provisions a Debian Bullseye VM
configure-guest-kernel
qemu-run             # Boot kernel under QEMU with GDB stub (port 1234)
gdb-run              # Attach GDB to running guest
load-module          # Cross-compile and insert a kernel module into the guest
vscode-setup         # Generate compile_commands.json for IntelliSense
```

### `#fpga-dev`

iCE40 FPGA toolchain: `yosys` for synthesis, `nextpnr` with GUI for place-and-route, `icestorm` for bitstream generation, `iverilog` for simulation, and `gtkwave` for waveform inspection.

### `#embedded-linux`

Cross-compilation environment targeting ARM (Raspberry Pi, BeagleBone Black). Provides two complete cross-compile toolchains with wrapper scripts exposing the standard binutils interface (`gcc`, `g++`, `ld`, `ar`, `objcopy`, `objdump`, etc). Includes U-Boot and BusyBox build dependencies, serial console tools (`minicom`, `picocom`, `bbb-serial`), and device tree utilities.

### `#gbdk-dev`

Game Boy development with GBDK 2020 (v4.2.0), mGBA emulator, and a GDB setup for stepping through ROM code.

## Multi-Host Management & CI

All 8 hosts are evaluated on every PR via GitHub Actions:

```yaml
for host in gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas:
  nix eval --impure .#nixosConfigurations.${host}.config.system.build.toplevel.drvPath
```

This catches evaluation errors across the entire fleet before anything reaches `main`. Each host runs `rebuild` locally (a wrapper that auto-detects hostname and runs `nixos-rebuild switch`) — the flake target is never hardcoded, which prevents applying the wrong configuration to a machine.

**Hosts:**

| Host | Role |
|---|---|
| `gaming-pc` | Primary workstation, kernel dev, 4-monitor setup |
| `asus-laptop` | ROG G14 — dual GPU (iGPU + RTX), `asusctl` |
| `asus-m15` | ROG M15 laptop |
| `optiplex` | Secondary desktop — Windows 7 themed KDE |
| `optiplex-nas` | Headless homelab server (192.168.1.76) |
| `atl-mini-pc` | Atlanta mini PC |
| `blaney-pc` | Friend's machine — learning NixOS |
| `justus-pc` | Friend's machine |

Secrets are managed with SOPS + age, keyed from each host's SSH host key. WireGuard is configured declaratively for both server and client roles.

## Custom Packages

Three packages defined in [`pkgs/`](pkgs/), built from source and exposed as flake outputs:

- **`worldmonitor`** — Real-time global intelligence dashboard with AI-powered news synthesis
- **`spotatui`** — Spotify TUI client (Rust)
- **`tuisic`** — TUI music streaming app with vim motions (C++)

## Homelab

The `optiplex-nas` host runs a full media stack, all configured declaratively:

- **Jellyfin** with Intel VA-API hardware transcoding
- **Radarr / Sonarr / Prowlarr / Bazarr** — media automation
- **Jellyseerr** — request management
- **Transmission** — torrent client behind Mullvad VPN
- **FlareSolverr** — Cloudflare bypass for indexers
- **Samba** — public share + LUKS-encrypted private share

A custom `media-linker` service queries the Jellyseerr API and creates per-user Jellyfin libraries via hardlinks from the master media store — so users see only what they requested, without duplicating storage.

Storage layout: `/mnt/storage` (btrfs RAID1), `/mnt/cache` (SSD), `/mnt/private` (LUKS encrypted). Media directories use SGID (2775) with a shared `media` group so all services can write without permission conflicts.

## Gaming

The `gaming` profile bundles Steam, Lutris, Heroic, Wine (WoW64), Dolphin, MangoHud, Gamescope, gamemode, and GPU Screen Recorder. Peripheral support includes OpenRGB, OpenRazer, CKB-next (with a systemd shutdown hook to kill the lights), Solaar, and input-remapper. GameCube adapter udev rules handle both official Nintendo and Mayflash adapters. XPadNeo loads the kernel module for Xbox controller support.

## Themes

Wayland components follow a functional/theme split — `functional.nix` modules provide keybindings, monitor layout, and service startup unconditionally; theme modules layer visual config on top via `mkForce` overrides. Two Hyprland themes:

- **`century-series`** — Cold War aviation cockpit aesthetic (F-100 through F-106, MiG-17/19/21). Per-app theming across Hyprland, Waybar, Kitty, Dunst, Rofi, Wofi, Swaylock, wlogout, Yazi, and btop.
- **`future-aviation`** — Modern aerospace look.

KDE themes include a full Windows 7 Aero recreation (fetching AeroThemePlasma from source) and a macOS Big Sur theme, each managed declaratively through plasma-manager.
