<!-- ~/nixos-config/docs/test-vms-and-ci.md -->
> **Read this when**: iterating on desktop/theme software config without disturbing a
> real host, or changing `.github/workflows/check.yml` / the self-hosted NAS runner.

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

