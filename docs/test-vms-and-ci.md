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

