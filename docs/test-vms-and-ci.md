<!-- ~/nixos-config/docs/test-vms-and-ci.md -->
> **Read this when**: iterating on desktop/theme software config without disturbing a
> real host, driving a test VM headlessly / capturing screenshots of a GUI change over
> SSH, or changing `.github/workflows/check.yml` / the self-hosted NAS runner.

# Test VMs & CI Build Job

Two throwaway QEMU hosts exist for iterating on the fragile *software-config* surface
(aerothemeplasma, plasma, Hyprland, browser/app config) without disrupting gaming-pc or a
headless server. They are never installed to hardware — they share `hosts/vm-common.nix`
(VM sizing, guest agents, boot/FS stub) and force `nvidia`/`peripherals` **off**.

- **`vm-sandbox`** — kitchen-sink: KDE (windows7-alt aerotheme) + Hyprland (century-series),
  SDDM autologin. General ricing/experimentation.
- **`vm-blaney`** — mirrors blaney-pc's KDE/aerotheme + Hyprland *software* config (gaming
  stack and heavy packages trimmed) so his theme/plasma issues can be reproduced and fixed
  locally before pushing a `blaney/` PR to that remote machine.

Launch (needs KVM — run on gaming-pc, log in as the host user / password `vm`). The
`testvm` command (from `modules/nixos/common/commands.nix`) builds + launches in one step,
keeping the disk in `~/.cache/nixos-testvms/`:
```bash
testvm sandbox           # or: testvm blaney
testvm sandbox --clean   # discard the VM disk first for a fresh boot
```
Equivalent raw invocation:
```bash
nixos-rebuild build-vm --flake /home/lando/nixos-config#vm-sandbox --impure
./result/bin/run-*-vm
```

**Limitation — VMs cannot validate GPU/driver behaviour.** QEMU falls back to `llvmpipe`
software rendering, so the NVIDIA KMS/boot-hang, TTY-framebuffer, and WiFi-driver classes
are *not* reproducible in a VM. Those still rely on the real-hardware beta-host soak. The
VMs + build-CI target build-time and software-config regressions only.

## Driving a test VM headlessly (no display / over SSH)

`testvm` opens a GTK window, so it needs a desktop session. When you are on gaming-pc over
SSH — or running as a Claude session with no `DISPLAY` — run the VM **headless and drive it
over QMP** instead. QMP talks to the hypervisor, not the guest, so it works identically at
the bootloader, in `ly`, and inside a desktop session, and needs nothing installed in the
guest.

This is the procedure for "show me the feature working" when you cannot look at a screen:
it produced the verification screenshots for the blaney-pc shutdown guard (PR #151).

**1. Build the runner and launch it headless.**

```bash
nixos-rebuild build-vm --flake /home/lando/nixos-config#vm-blaney --impure
SCRATCH=/tmp/vmrun; mkdir -p "$SCRATCH"
NIX_DISK_IMAGE="$SCRATCH/disk.qcow2" \
QEMU_OPTS="-display none -qmp unix:$SCRATCH/qmp.sock,server=on,wait=off" \
  setsid ./result/bin/run-*-vm > "$SCRATCH/vm.log" 2>&1 &
```

`$QEMU_OPTS` is appended *after* the runner's own flags, so a later `-display none`
overrides its hardcoded `-display gtk`. `$QEMU_KERNEL_PARAMS` is likewise appended to the
guest kernel command line — the two env vars are the whole extension surface. Keep the disk
out of `~/.cache/nixos-testvms/` if you don't want to disturb a VM you are already using.

**2. Drive it with `scripts/vm-qmp.py`** (`nix shell nixpkgs#python3` — python is not on
PATH by default here):

```bash
export QMP_SOCK=$SCRATCH/qmp.sock
python3 scripts/vm-qmp.py status              # running / paused
python3 scripts/vm-qmp.py size                # framebuffer size, e.g. 1920x1080
python3 scripts/vm-qmp.py shot /tmp/s01.png
python3 scripts/vm-qmp.py type "vm"           # a literal string
python3 scripts/vm-qmp.py key ret             # or a combo: meta_l-ret, meta_l-backspace
python3 scripts/vm-qmp.py click 22 1060       # guest pixel coordinates
```

The loop is **screenshot → look at it → send the next input**. Read the PNG back (Claude
can view it directly; a human can `scp` it), decide where to click, repeat. Crop with
`magick <in> -crop WxH+X+Y +repage <out>` when you need to read small text in a 1080p shot.

**3. Faking time-dependent state.** Features that only fire on a schedule are otherwise
untestable without editing the repo. Pin the guest clock instead — this is how the shutdown
guard was shown inside its 12-hour window on a Thursday, with no config change at all:

```bash
QEMU_KERNEL_PARAMS="systemd.mask=systemd-timesyncd.service" \
QEMU_OPTS="-display none -qmp unix:$SCRATCH/qmp.sock,server=on,wait=off \
           -rtc base=2026-09-28T01:00:00" ...
```

`-rtc base=` takes **UTC** and only sets the *initial* clock, so masking `systemd-timesyncd`
is required or NTP steps the guest back to real time within seconds of the network coming
up and the staged condition silently evaporates.

**4. Deliver the screenshots.** Put them somewhere the person can actually look at them —
the NAS, in a dated subfolder so they don't litter a shared directory, with a short
`README.txt` recording how the state was staged (a screenshot of a faked clock is
misleading without it):

```bash
D=/mnt/storage/Landon/Captures/<feature>-$(date +%F)
ssh -J lando@192.168.1.189 lando@192.168.100.76 "mkdir -p '$D'"
scp -o ProxyJump=lando@192.168.1.189 shots/* lando@192.168.100.76:"$D/"
```

(The NAS has no direct SSH on its legacy `192.168.1.76` address — the jump host is
mandatory. See [networking.md](networking.md).)

**Gotchas, all of them hit in practice:**

- **The resolution changes at login** (1280x800 in `ly` → 1920x1080 in the session), and
  QEMU's absolute pointer axes are a fixed 0..32767 range regardless. `vm-qmp.py` re-reads
  the framebuffer size from a throwaway screendump on every invocation for exactly this
  reason; if you write your own driver, do the same or your clicks land in the wrong place
  after login.
- **Clicking needs `-device usb-tablet`**, which the nixos build-vm runner already passes.
  Without an absolute pointing device there is no way to aim.
- **`ly` remembers the last user and session**, so the first boot needs the session picker
  (Up to the session row, Left/Right to cycle — it is a long list, screenshot as you go) but
  later boots land straight on the password field.
- **Powering the guest off kills the QMP socket.** Any command after that fails with
  "QMP connection closed"; that is the guest shutting down, not a driver bug. If you are
  capturing something that ends in a poweroff, take the shots in a tight loop.
- **`pkill -f qemu-system-x86_64` to stop it**, and delete the `result` symlink the
  build-vm leaves in the repo root.

## Testing Hyprland without KVM (nested in KWin)

blaney-pc has no `/dev/kvm` (SVM is off in its firmware), so the VMs above would run under
TCG — far too slow for a llvmpipe desktop. A **real, GPU-rendered Hyprland can run nested**
there instead, on the branch's generated config, without touching the live session. This
is how the Glade desktop ([theming.md](theming.md#the-glade-theme)) was verified while
insideabush stayed logged into XFCE: every click below was actually made and checked.

The shape, as insideabush (`runuser -u insideabush --`), all state under one short
directory such as `/tmp/ghy` (Wayland socket paths are limited to 108 bytes, so the
scratchpad is too long):

1. **Build the branch's home generation**
   (`.#nixosConfigurations.<host>.config.home-manager.users.<user>.home.activationPackage`)
   and copy its `home-files` into a throwaway `$HOME` (`cp -rL`). Make a test copy of the
   desktop's `.config/hypr/desktops/<name>.conf` (`hyprland.conf` only `source`s it)
   **without** the `exec-once` lines that reach outside the
   test: `dbus-update-activation-environment` (it would rewrite the REAL user manager's
   environment), anything `systemctl --user`, `nm-applet`, `polkit`, `paplay`,
   `century-night`, `restore-monitors`. Append `monitor=WAYLAND-1,1920x1080,0x0,1`.
2. **Start from a clean environment** (`env -i`, then set `HOME`, `XDG_RUNTIME_DIR`,
   `XDG_CONFIG_HOME`, `XCURSOR_PATH`, `XDG_DATA_DIRS`, `PATH`). Inherited root variables
   crash Hyprland — e.g. `XCURSOR_PATH` pointing into `/root`.
3. **Host it in `kwin_wayland --virtual --width 1920 --height 1080 --socket <name>`** under
   `dbus-run-session`, and run `Hyprland -c <test.conf>` with `WAYLAND_DISPLAY=<name>`.
   Headless **sway is too old**: Hyprland's Wayland backend needs `xdg_wm_base` v6 and
   sway 1.12 offers 5 (`CBackend::create() failed!`). Hyprland has no headless-only mode.
4. **Talk to the nested session** with its own `WAYLAND_DISPLAY` (its `wayland-1` in the test
   runtime dir), `HYPRLAND_INSTANCE_SIGNATURE` (newest dir in `$XDG_RUNTIME_DIR/hypr`), and
   the session's `DBUS_SESSION_BUS_ADDRESS` read from the Hyprland process' environ
   (waybar exits without a bus). `grim` against that socket screenshots it.
5. **Plug in a mouse that stays plugged in:** `scripts/nested-hyprland/vpointer.c`
   (`nix-build scripts/nested-hyprland/vpointer.nix`), fed from a FIFO
   (`tail -f fifo | vpointer W H`). The nested session has no pointer, so `wl_seat`
   advertises none and GTK clients never create one; `wlrctl` adds a pointer only for the
   instant of each command, so clicks never arrive. Title-bar drags need its `rel` moves,
   and a moved window glides there over a few hundred ms — read positions after it settles.
6. **A second monitor:** `hyprctl output create wayland` plus a `monitor=WAYLAND-2,...` rule
   (`create headless` comes up 0x0). Programs that read the monitor list at startup (the
   glade) must be restarted afterwards.

Traps that cost time:

- **Stop the test by its runtime dir, never by process name.** List the PIDs whose environ
  has `XDG_RUNTIME_DIR=/tmp/ghy/rt` and kill those. A name match (`pkill -f portal`,
  `gvfsd`, `at-spi`, …) also hits the REAL session's helpers — that happened once, and
  they had to be restarted with `systemctl --user start`. Unmount the test's
  `$XDG_RUNTIME_DIR/{gvfs,doc}` FUSE mounts before deleting it.
- waybar's process name is `.waybar-wrapped`, so `pkill -x waybar` misses it and a
  restart stacks a second bar.
- waybar's `pulseaudio` module leaks descriptors until "Too many open files" when no sound
  server is reachable; point `PULSE_SERVER` at the real one (read-only use).
- The first GTK app in a fresh `$HOME` takes several seconds (fontconfig cache) — wait
  before deciding a menu did not open.

## CI build job

`.github/workflows/check.yml` has two jobs:
- **`evaluate`** (GitHub-hosted `ubuntu-latest`) — fast `nix eval …drvPath` for **all**
  hosts incl. the two VMs. Catches type/option errors and stale fetch hashes.
- **`build`** (self-hosted runner on **optiplex-nas**) — `nix build`s only the fragile
  *source-built* derivations, **not** full toplevels: aerothemeplasma's ~13 KWin/Plasma
  C++ derivations (via `vm-sandbox.pkgs.*`) and the openrazer out-of-tree kernel module
  (`blaney-pc.config.boot.kernelPackages.openrazer`). These are the things that break on
  nixpkgs bumps (PR #74/#83 class). Full toplevels are deliberately avoided — they drag in
  browsers/steam/kernels that are usually cached but OOM this modest NAS when momentarily
  uncached, for no benefit to what we test. The NAS store is warm from the nightly
  flake-updater, so these builds are cheap and incremental.

**Security posture:** self-hosted runners must not execute untrusted code. The `build` job
is gated (`if:`) to run only on `push` to repo branches and **same-repo** PRs — never fork
PRs (fork PRs still get the `evaluate` gate). Keep the repo setting "Require approval for
all outside collaborators". The runner is defined in `hosts/optiplex-nas/default.nix`
(`services.github-runners.nixos-config-ci`) and needs the `github-runner-token` sops secret
(a PAT with repo Administration read/write) in `secrets/optiplex-nas.yaml` before it can
register — verify it registers on the NAS before merging any change that enables it.

