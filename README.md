# nixos-config

A modular, multi-host NixOS flake managing 8 machines — development workstations, laptops, a homelab server, and machines for friends and family. Everything is declarative, version-controlled, and evaluated in CI on every push.

## Development Shells

Four hermetic `nix develop` environments, each self-contained with toolchains, build scripts, and helper utilities. The shells are defined as NixOS module options and exposed as flake outputs — the shell derivations live inside `customConfig.profiles.development.*` and are referenced directly in `flake.nix`:

```nix
devShells.x86_64-linux = {
  kernel-dev    = pkgs.mkShell referenceHostConfig.customConfig.profiles.development.kernel.devShell;
  fpga-dev      = referenceHostConfig.customConfig.profiles.development.fpga-ice40.devShell;
  embedded-linux = referenceHostConfig.customConfig.profiles.development.embedded-linux.devShell;
  gbdk-dev      = ...;
};
```

### `#fpga-dev`

iCE40 FPGA open-source toolchain:

| Tool | Role |
|---|---|
| `yosys` | RTL synthesis |
| `nextpnr` (with GUI) | Place-and-route |
| `icestorm` | Bitstream generation and device programming (`iceprog`) |
| `iverilog` | Verilog simulation |
| `gtkwave` | Waveform inspection |

### `#embedded-linux`

Cross-compilation environment targeting ARM (Raspberry Pi via `pkgsCross.raspberryPi`, BeagleBone Black via `pkgsCross.armv7l-hf-multiplatform`). Both toolchains are exposed through per-target wrapper scripts — so `armv7l-unknown-linux-gnueabihf-gcc`, `g++`, `ld`, `ar`, `nm`, `objcopy`, `objdump`, `ranlib`, `readelf`, `strip`, etc., all land directly in `$PATH`.

Custom scripts bundled into the shell:

- **`bbb-serial`** — auto-detects USB serial adapters (`/dev/ttyUSB*`, `/dev/ttyACM*`) and opens a picocom session at 115200 baud
- **`kconfig-menuconfig`** — wraps `make menuconfig` with `HOSTCC="gcc -std=gnu89"` to fix GCC 14+ rejection of C89-style `main()` in kconfig's lxdialog check

The shell also exports `HOSTCFLAGS` and `HOSTLDFLAGS` pointed at Nix store paths for ncurses, so `make menuconfig` works in kernel and BusyBox source trees without FHS assumptions.

U-Boot and BusyBox build dependencies (`autoconf`, `automake`, `bc`, `bison`, `dtc`, `flex`, `swig`, `ubootTools`), QEMU full, SD card utilities (`dosfstools`, `e2fsprogs`), and serial console tools (`minicom`, `picocom`) are all included.

### `#kernel-dev`

Full Linux kernel development environment with a QEMU guest workflow. Build toolchain: `gcc`, `clang`/`llvm`/`lld`, `make`, `flex`, `bison`, `pahole`, `elfutils`. Static analysis: `sparse`, `cppcheck`, `flawfinder`. Profiling and tracing: `perf`, `trace-cmd`, `rt-tests`, `smem`, `tuna`. `bear` for `compile_commands.json` generation.

Custom scripts composing the dev loop:

| Script | What it does |
|---|---|
| `create-guest-image` | Provisions a Debian Bullseye VM image using syzkaller's `create-image.sh`, configures `systemd-networkd`, installs SSH keys |
| `configure-guest-kernel` | Merges a checked-in `.config` fragment onto `defconfig` via `merge_config.sh`, then runs `olddefconfig` |
| `qemu-run` | Boots the guest kernel under QEMU-KVM with `-s -S` (GDB stub on port 1234) |
| `gdb-run` | Attaches GDB to the running guest, loading `vmlinux-gdb.py` |
| `ssh-guest` | SSHes into the guest VM via the provisioned key |
| `lkm-run` | Builds a kernel module against the host kernel source, SCP-transfers it to the guest, and `insmod`s it |
| `lkm-dev` | Builds/lints a module; passes `FNAME_C` and `KDIR` to support Kaiwan Billimoria-style LKM Makefiles |
| `load-module` | Low-level SCP + remote `insmod` for a prebuilt `.ko` |
| `shutdown-guest` | Graceful SSH poweroff with timeout fallback to `pkill` |
| `vscode-setup` | Runs `bear` to generate `compile_commands.json`, then templates `.vscode/c_cpp_properties.json` with the Nix store GCC path |

### `#gbdk-dev`

Game Boy development: GBDK 2020 (v4.2.0), mGBA emulator, GDB for ROM debugging.

---

## CI/CD Pipeline

### GitHub Actions — Multi-Host Eval

Every push to `main` or `update/*` and every PR triggers a full evaluation of all 9 host configurations:

```yaml
hosts=(gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas mini-server)
for host in "${hosts[@]}"; do
  nix eval --impure ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath"
done
```

This catches type errors, missing imports, and broken module references across the entire fleet before anything reaches `main`. `NIXPKGS_ALLOW_UNFREE=1` is set so proprietary packages (NVIDIA drivers, Steam) don't block eval.

### Automated Weekly Flake Updates

A systemd service on `optiplex-nas` runs every Monday at 03:00 and implements the full update pipeline without human intervention:

1. Creates branch `update/YYYY-WNN`, runs `nix flake update`
2. Builds all 9 hosts with per-host timeout tracking; results are posted as a Markdown table in the PR body
3. Opens a GitHub PR via `gh pr create` with label `flake-update`
4. `gaming-pc` (`betaTesterHost = true`) auto-tracks the `update/*` branch on next `sync` — receives the update one week early
5. After 7 days, the NAS auto-merges if the `update-blocked` label is absent; all other hosts pick it up on their next `sync`

Blocking a bad update is a single label: `gh pr edit <PR> --add-label update-blocked`. The NAS respects the label and skips the merge.

### Local Rebuild Workflow

`rebuild` is a host-aware wrapper around `nixos-rebuild switch --flake /home/lando/nixos-config#$(hostname) --impure --max-jobs auto`. The hostname is never hardcoded — applying the wrong host config to a machine can delete user accounts, break authentication, or prevent boot. `rebuild-test` runs `nixos-rebuild test`, which activates the config without creating a boot entry and reverts on reboot.

---

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

Key configuration sections in `customConfig`:

| Namespace | Purpose |
|---|---|
| `user` | Account settings, shell, permissions |
| `system` | Hostname, timezone, state version |
| `desktop` | Desktop environments, display manager, idle timeouts |
| `hardware` | NVIDIA, monitors, touchpad, laptop flags |
| `profiles.development` | Dev shell flags (kernel, FPGA, embedded Linux, GBDK) |
| `services` | SSH, WireGuard (server + client roles) |
| `homelab` | Jellyfin, arr stack, flake-updater, media-linker |

---

## Secrets Management

Secrets use [sops-nix](https://github.com/Mic92/sops-nix) with age keys derived from each host's SSH ed25519 host key at runtime — no separate key distribution step during bringup:

```nix
sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
```

`.sops.yaml` maps host public keys to creation rules. Per-host secret files live in `secrets/<hostname>.yaml`. Current usage: user password hashes (`hashedPasswordFile` + `mutableUsers = false`) and media service API keys (Jellyseerr, Radarr, Sonarr).

WireGuard is configured declaratively for both server and client roles, with private keys referenced via `sops.secrets.*`.

---

## Custom Packages

Three packages in [`pkgs/`](pkgs/), each built from source as a proper Nix derivation and exposed as flake outputs:

- **`spotatui`** — Spotify TUI client; built with `rustPlatform.buildRustPackage`, links against `alsa-lib`, `dbus`, and PipeWire
- **`tuisic`** — TUI music streaming app with vim motions; `stdenv.mkDerivation` with CMake, links `ftxui`, `mpv-unwrapped`, `sdbus-cpp`
- **`worldmonitor`** — Real-time global intelligence dashboard; AppImage wrapped with `appimageTools.wrapType2`, injecting `webkitgtk_4_1` and `glib-networking` to fix black screens on non-Ubuntu distros

---

## Multi-Host Management

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
| `mini-server` | BeeLink AZW mini PC — GNOME + game server (Astroneer) |
| `aj-laptop` | AJ's laptop *(config pending merge)* |

Each host is a `nixosSystem` call in `flake.nix` pulling in its `hosts/<hostname>/default.nix`, home-manager, NUR, disko, sops-nix, and `nixos-hardware` as appropriate.

---

## Homelab

The `optiplex-nas` host runs a full media stack, all configured declaratively:

- **Jellyfin** with Intel VA-API hardware transcoding
- **Radarr / Sonarr / Prowlarr / Bazarr** — media automation
- **Jellyseerr** — request management
- **Transmission** — torrent client behind Mullvad VPN
- **FlareSolverr** — Cloudflare bypass for indexers
- **Samba** — public share + LUKS-encrypted private share

A custom `media-linker` service queries the Jellyseerr API and creates per-user Jellyfin libraries via hardlinks from the master media store — users see only what they requested without duplicating storage.

Storage layout: `/mnt/storage` (btrfs RAID1), `/mnt/cache` (SSD), `/mnt/private` (LUKS encrypted). Media directories use SGID (2775) with a shared `media` group so all services can write without permission conflicts.

---

## Gaming

The `gaming` profile bundles Steam, Lutris, Heroic, Wine (WoW64), Dolphin, MangoHud, Gamescope, gamemode, and GPU Screen Recorder. Peripheral support includes OpenRGB, OpenRazer, CKB-next (with a systemd shutdown hook to kill the lights), Solaar, and input-remapper. GameCube adapter udev rules handle both official Nintendo and Mayflash adapters. XPadNeo loads the kernel module for Xbox controller support.

---

## Themes

Wayland components follow a functional/theme split — `functional.nix` modules provide keybindings, monitor layout, and service startup unconditionally; theme modules layer visual config on top via `mkForce` overrides. Two Hyprland themes:

- **`century-series`** — Cold War aviation cockpit aesthetic (F-100 through F-106, MiG-17/19/21). Per-app theming across Hyprland, Waybar, Kitty, Dunst, Rofi, Wofi, Swaylock, wlogout, Yazi, and btop.
- **`future-aviation`** — Modern aerospace look.

KDE themes include a full Windows 7 Aero recreation (fetching AeroThemePlasma from source) and a macOS Big Sur theme, each managed declaratively through plasma-manager.
