# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS configuration flake that manages multiple hosts with shared modules. The configuration uses a custom options system (`customConfig`) to provide type-safe, declarative configuration across all hosts.

## Choosing the Right Host to Work On

**At the start of a session, before diving in, check whether the task is better handled natively on a different host** — many features/fixes can only be rebuilt, tested, and verified on the machine that actually runs the affected component. If the current host isn't the ideal one, say so and recommend switching before doing the work, rather than making a change that can't be verified here.

Rough guide for the three commonly-used hosts:

- **gaming-pc** — primary desktop (KDE + Hyprland) and beta-tester host. Best for: desktop environments, Hyprland/Waybar/theme work, SDDM/display-manager, gaming profile, general development, and anything needing a display to verify.
- **optiplex-nas** — headless homelab NAS. Best for: Jellyfin, Samba, the *arr stack, mediaLinker, media/storage layout, and homelab service config.
- **mini-server** — headless server on the server LAN (behind optiplex-fw). Best for: Home Assistant, Wyoming voice satellite, the game-control dashboard, and game servers.

When a task clearly belongs to another host (e.g. a Jellyfin tweak while on gaming-pc), recommend the user start the session there so it can be verified in place. Cross-machine changes that genuinely can't be tested on the current host follow the branch → PR → verify-on-target workflow below.

## Development Commands

### Running as sudo (Claude Code)

When Claude Code is launched with `sudo`, it inherits `SSH_AUTH_SOCK` from the parent session, but the SSH key may not be loaded into the agent yet. Before any `git push` or SSH operation, check if the key is available:

```bash
ssh-add -l 2>/dev/null || ssh-add /home/lando/.ssh/id_ed25519
```

This is a no-op if the key is already loaded.

**File ownership**: When running as sudo, `$USER` resolves to `root`, not `lando`. Always use the explicit path:

```bash
sudo chown -R lando:users /home/lando/nixos-config
```

Never use `sudo chown -R $USER:users ~/nixos-config` — both `$USER` and `~` expand to root when running as sudo, making it a no-op or targeting the wrong path.

**Git identity**: When making commits or pushes as sudo, git may not inherit the correct user config. Set identity explicitly if needed:

```bash
git -c user.name="lando" -c user.email="landonreekstin@gmail.com" commit ...
```

Or verify the git config is set correctly before committing:
```bash
git config user.name   # should be: lando
git config user.email  # should be: landonreekstin@gmail.com
```

### System Management
- `rebuild` - Rebuild the current host configuration using the local flake
- `sync` - Pull latest changes from the remote repository (handles merge conflicts)
- `update` - Update flake inputs (requires `updateCmdPermission` enabled)
- `upgrade` - Update flake inputs and rebuild system in one command
- `post-install` - Complete initial setup after fresh NixOS installation

### NixOS Rebuild Commands

**CRITICAL: Always use the `rebuild` command instead of manually running `nixos-rebuild`.** The `rebuild` command automatically detects the current host and uses the correct flake target. Manually specifying the wrong hostname (e.g., `--flake .#blaney-pc` on `gaming-pc`) will apply the wrong configuration, potentially removing the user account and causing system boot failures.

```bash
# CORRECT - Always use this:
rebuild

# DANGEROUS - Never manually specify hostname:
# sudo nixos-rebuild switch --flake ~/nixos-config#<hostname> --impure
```

For testing changes without switching, use `rebuild` with the test argument via nixos-rebuild directly, but let the system identify itself:
```bash
sudo nixos-rebuild test --flake /home/lando/nixos-config#$(hostname) --impure
```

Note: Use the absolute path `/home/lando/nixos-config` rather than `~/nixos-config` — when running as sudo, `~` expands to `/root`.

### Development Shells
Access development environments via:
```bash
nix develop .#kernel-dev      # Linux kernel development
nix develop .#fpga-dev        # FPGA development (ice40)
nix develop .#embedded-linux  # Embedded Linux cross-compilation
nix develop .#gbdk-dev        # Game Boy development
```

## Architecture

### Flake Structure
- `flake.nix` - Main entry point defining inputs, outputs, and host configurations
- `hosts/` - Host-specific configurations, each containing `default.nix` and `hardware-configuration.nix`
- `modules/nixos/` - System-level NixOS modules
- `modules/home-manager/` - User-level Home Manager modules

### Configuration System
All configuration is managed through the `customConfig` option set defined in `modules/nixos/common-options.nix`. This provides:
- Type-safe configuration options with validation
- Centralized defaults and documentation
- Consistent interface across all hosts

### Key Configuration Sections
- `customConfig.user` - User account settings (name, email, shell, permissions)
- `customConfig.system` - System basics (hostname, timezone, state version)
- `customConfig.desktop` - Desktop environments (KDE, Hyprland, Cosmic)
- `customConfig.hardware` - Hardware-specific options (NVIDIA, peripherals)
- `customConfig.profiles` - Feature bundles (gaming, development)
- `customConfig.services` - System services (SSH, WireGuard, homelab)

### Host Examples
- `gaming-pc` - Primary development machine with kernel dev tools
- `optiplex` - Windows 7 themed KDE desktop
- `asus-laptop` - Laptop configuration with NVIDIA dual GPU
- `optiplex-nas` - Homelab server with Jellyfin and Samba
- `blaney-pc` - Experimental/learning environment (see Host-Specific Guidelines)

## Working with Themes

### Plasma Themes
- `windows7` / `windows7-alt` - Complete Windows 7 recreation with custom plasmoids
- `bigsur` - macOS Big Sur appearance
- `aerothemeplasma` - Base Aero theme system

Theme configuration is set via `customConfig.homeManager.themes.kde`.

### Custom SDDM Themes
Configure via `customConfig.desktop.displayManager.sddm.customTheme` with wallpaper, colors, and styling options.

### Hyprland Themes
- `future-aviation` - Sleek aerospace aesthetic with modern fighter jet inspiration
- `century-series` - Cold War aviation cockpit theme (F-100 through F-106, MiG-17/19/21)

Theme configuration is set via `customConfig.homeManager.themes.hyprland`.

### Functional vs Theme Paradigm for Wayland Components

The Wayland component architecture follows a strict separation of concerns between **functional** and **theme** modules:

#### Functional Modules (`modules/home-manager/*/functional.nix`)
**Always active** when the component is enabled. Provide:
- **Essential functionality**: Keybindings, startup commands, base settings
- **Hardware configuration**: Monitor layouts, input settings
- **Service management**: Process startup, systemd services
- **Package dependencies**: Required binaries and tools
- **Default configurations**: Base module settings with `mkDefault` priority

Examples:
- `hyprland/functional.nix` - Keybindings, exec-once, monitor config, variables
- `waybar/functional.nix` - Module layout, click actions, base formatting

#### Theme Modules (`modules/home-manager/themes/*/`)
**Conditionally active** when theme is selected. Provide only:
- **Visual styling**: Colors, fonts, borders, animations
- **Theme-specific overrides**: Custom formats, icons, CSS styling
- **Wallpapers and assets**: Theme-specific media files
- **Aesthetic configuration**: Gaps, rounding, shadows, effects
- **Priority overrides**: Use `mkForce` for conflicting visual settings

Examples:
- `themes/century-series/hyprland.nix` - MFD borders, cockpit colors, tactical animations
- `themes/century-series/waybar.nix` - Aviation terminology, instrument panel styling

#### Key Principles
1. **Themes never duplicate functional settings** - Always inherit base functionality
2. **Functional modules use `mkDefault`** - Allow themes to override with `mkForce`
3. **Settings merge cleanly** - No conflicts between functional base and theme overrides
4. **Themes remain portable** - Can be applied to any host without breaking functionality
5. **Functional modules stay stable** - Theme changes don't affect core functionality

#### Example Architecture
```nix
# functional.nix (always active)
bind = mkDefault [
  "$mainMod, SPACE, exec, $menu"
  "$mainMod, RETURN, exec, $terminal"
];

# theme.nix (when theme active) 
general = {
  border_size = mkForce 3;  # Override for theme
  "col.active_border" = "rgb(ff9e3b)";  # Theme colors
};
```

This ensures themes provide visual identity while maintaining core Wayland functionality.

## Development Profiles

Enable development environments via `customConfig.profiles.development`:
- `kernel.enable` - Linux kernel development with proper toolchain
- `embedded-linux.enable` - Cross-compilation for embedded targets
- `fpga-ice40.enable` - FPGA development tools
- `gbdk.enable` - Game Boy development kit

## Hardware Support

The configuration supports:
- NVIDIA graphics (desktop and laptop dual-GPU setups)
- ASUS laptop-specific tools (asusctl)
- RGB peripherals (OpenRGB, OpenRazer, CKB-next)
- Input remapping and device management

## File Management

### Module Header Format
All modules should follow this standard header format:
```nix
# ~/nixos-config/path/to/module.nix
{ config, pkgs, lib, ... }:
```

### Making Changes
1. Edit configuration files in your local `~/nixos-config` clone
2. `sudo chown -R lando:users /home/lando/nixos-config`
3. `rebuild` — **do not commit until this succeeds and changes are verified**
4. Commit and push changes when satisfied
5. Other machines can `sync` to pull updates

### Commit Message Style
Follow the established commit message convention:
```
type(scope): description
```

**Types**: `feat`, `fix`, `tweak`, `pkg`, `test`, `docs`
- `feat` - New features or functionality
- `fix` - Bug fixes
- `tweak` - Minor adjustments or configuration changes
- `pkg` - Package additions or changes
- `test` - Testing changes
- `docs` - Documentation updates

**Guidelines**:
- Use lowercase for the description
- No period at the end
- Keep descriptions concise
- Scope should be the relevant host or module name
- **Do not add Co-Authored-By or AI attribution lines**

**Examples**:
```
feat(gaming): added dolphin emulator
fix(peripherals): missing import
tweak(gaming-pc): enable ckb-next
docs(claude): add blaney-pc guidelines
```

## Automated Weekly Flake Updates (CI/CD Pipeline)

Flake updates are automated via a systemd service on `optiplex-nas` that runs every Monday at 03:00.

### How it works

1. NAS creates branch `update/YYYY-WNN`, runs `nix flake update`, builds all 9 hosts, opens a GitHub PR
2. **gaming-pc** (`betaTesterHost = true`) automatically tracks the latest `update/*` branch on the next `sync` — it receives the update one week before everyone else
3. After **7 days**, the NAS auto-merges the PR if no `update-blocked` label is present
4. All other hosts pick up the update on their next `sync` after the merge

### Blocking a bad update

If a flake update causes a runtime issue (e.g., broken NVIDIA driver, broken audio) that passes eval but breaks the live system:

1. Go to the open `chore(flake): weekly update YYYY-WNN` PR on GitHub
2. Add the **`update-blocked`** label
3. The NAS will NOT auto-merge while this label is present
4. To roll back gaming-pc immediately: `git checkout main && rebuild`
5. When you have a fix, push it to the `update/*` branch, remove the label — the next Monday run will auto-merge

### Manual trigger

To manually run the updater on optiplex-nas:
```bash
sudo systemctl start flake-updater
journalctl -u flake-updater -f
```

### Beta host behavior

On gaming-pc, running `sync` when a `update/*` branch exists on remote will automatically switch to it. When no update branch exists (post-merge), `sync` falls back to main. This is transparent — no user action needed.

### For Claude: how to handle common requests

**"Approve the update" / "let it merge"** — do nothing. The NAS auto-merges after 7 days automatically. There is no action needed; manually merging via `gh pr merge` is wrong and bypasses the soak period.

**"Block the update" / "don't merge this"**
```bash
# Find the open update PR
gh pr list --repo landonreekstin/nixos-config --label flake-update
# Add the block label (use the PR number from above)
gh pr edit <PR_NUMBER> --repo landonreekstin/nixos-config --add-label "update-blocked"
```

**"Fix the update" / "push a fix to the update branch"**
```bash
# Find the current update branch
git branch -r --list 'origin/update/*' | sort -V | tail -1
# On gaming-pc, the branch is already checked out; on other machines, check it out:
git checkout -B update/YYYY-WNN origin/update/YYYY-WNN
# Make the fix, rebuild/verify, then:
git push origin update/YYYY-WNN
# After confirming the fix works, remove the block label if present:
gh pr edit <PR_NUMBER> --repo landonreekstin/nixos-config --remove-label "update-blocked"
```

**"Roll back gaming-pc"** — gaming-pc is the only host that auto-tracks the update branch:
```bash
git checkout main && rebuild
```

---

### Git Workflow

**CRITICAL: Always test before committing.** If the current machine can test the change, it MUST be rebuilt and verified before any commit is made. Never commit untested configuration changes — not even "obviously correct" ones.

**Branching strategy**:
- **Direct to main**: Documentation changes (`docs`), minor tweaks (`tweak`), and simple additions like adding a package can be committed directly to main after verification
- **Feature/PR branches**: Use branches for changes that are being developed on the local machine. Rebuild and verify on the branch first, then open a PR to merge into main. Also use branches for changes that can only be tested on a different machine — in that case, note in the PR that in-person testing is needed.
- **Never commit broken changes to main**: Only merge to main once changes have been rebuilt, tested, and verified to work

**Workflow by scenario**:
1. **Locally testable feature/fix**: Branch → Edit → chown → Rebuild → Verify → Commit → PR → Merge
2. **Cross-machine change**: Branch → Edit → Eval-check → Commit → PR (note needs in-person test on target machine) → Test on target → Merge when verified
3. **Documentation/minor tweak**: Edit → Commit to main (no rebuild needed for docs-only changes)

**The rule in plain terms**: commit comes *after* a successful rebuild and manual verification, never before. The only exception is changes that require a different machine to test — those go into a PR and are merged once verified on the target host.

**Do not open a PR until the change has been tested on the machine currently being developed on.** If Claude Code is running on `asus-laptop` and the change targets `asus-laptop`, do a `rebuild` and verify it works *before* creating the PR — not after. PRs should represent verified, working changes, not speculative ones.

### Hardware Configurations
Hardware configs are auto-generated during installation and should not be manually edited. They're stored per-host in `hosts/<hostname>/hardware-configuration.nix`.

## Test VMs & CI Build Job

Two throwaway QEMU hosts exist for iterating on the fragile *software-config* surface
(aerothemeplasma, plasma, Hyprland, browser/app config) without disrupting gaming-pc or a
headless server. They are never installed to hardware — they share `hosts/vm-common.nix`
(VM sizing, guest agents, boot/FS stub) and force `nvidia`/`peripherals` **off**.

- **`vm-sandbox`** — kitchen-sink: KDE (windows7-alt aerotheme) + Hyprland (century-series),
  SDDM autologin. General ricing/experimentation.
- **`vm-blaney`** — mirrors blaney-pc's KDE/aerotheme + Hyprland *software* config (gaming
  stack and heavy packages trimmed) so his theme/plasma issues can be reproduced and fixed
  locally before pushing a `blaney/` PR to that remote machine.

Launch (needs KVM — run on gaming-pc, log in as the host user / password `vm`):
```bash
nixos-rebuild build-vm --flake /home/lando/nixos-config#vm-sandbox --impure
./result/bin/run-*-vm
```

**Limitation — VMs cannot validate GPU/driver behaviour.** QEMU falls back to `llvmpipe`
software rendering, so the NVIDIA KMS/boot-hang, TTY-framebuffer, and WiFi-driver classes
are *not* reproducible in a VM. Those still rely on the real-hardware beta-host soak. The
VMs + build-CI target build-time and software-config regressions only.

### CI build job

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

## Installation

### Preferred: Remote deploy via nixos-anywhere (LAN or VPN)

**One-time USB creation** (reusable for all future installs):
```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
sudo dd if=$(readlink -f result)/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

**Deploy workflow** (run from gaming-pc):
1. Boot target from the installer USB — SSH starts automatically with lando's key
2. Find the target IP (`nmap -sn 192.168.1.0/24` or check router DHCP)
3. From gaming-pc:
   ```bash
   ./scripts/deploy-host.sh <hostname> <target-ip>
   # For VPN/WireGuard: ./scripts/deploy-host.sh <hostname> <wg-ip> 22
   ```
4. Script handles: age key derivation, `.sops.yaml` update, secrets encryption,
   disk wipe/partition (disko), NixOS install, hardware config capture
5. After target reboots into NixOS, commit from gaming-pc:
   ```bash
   git add hosts/<hostname>/hardware-configuration.nix secrets/<hostname>.yaml .sops.yaml
   git commit -m "feat(<hostname>): deploy — hardware config and age key"
   git push
   ```
6. On lando's machines only: SSH in and run `post-install` to set up GitHub SSH access

### Fallback: On-target install (no LAN access to gaming-pc)

The installer USB also provides a helper that clones the repo and runs the
on-target installer automatically:
```bash
sudo nixos-install-local <hostname> <username>
```

Or manually (from a live NixOS ISO):
```bash
git clone https://github.com/landonreekstin/nixos-config.git /tmp/nixos-config
sudo /tmp/nixos-config/scripts/install-new-host.sh <hostname> <username>
```

### New host checklist

Before deploying, the host config must exist in git:
- `hosts/<hostname>/default.nix` — with `sopsPassword = true` in the user block
- `hosts/<hostname>/disko-config.nix` — disk layout
- `hosts/<hostname>/hardware-configuration.nix` — placeholder (`{}`) or generated
- `.sops.yaml` — anchor `&<hostname>` with `age1PLACEHOLDER_<hostname>` and a
  creation rule for `secrets/<hostname>.yaml`

After first deploy, `scripts/deploy-host.sh` fills in the real age key and
generates the hardware config automatically.

After first boot, run `post-install` to complete setup and establish Git access.

## Homelab Services

Available via `customConfig.homelab`:
- Jellyfin media server
- Samba file sharing
- *arr stack (Radarr, Sonarr, Prowlarr, Bazarr)

## OpenBSD Firewall (optiplex-fw)

The only non-NixOS host in the homelab. Works perfectly and is not managed by NixOS — it just needs to be understood when NixOS service changes also require firewall/VPN changes (new port forward, new WireGuard peer, etc.).

**Config files**: tracked in the private `github.com:landonreekstin/openbsd-dotfiles` repo, cloned at `~/openbsd-dotfiles/` on optiplex-fw. The live files on the box are always the source of truth.

### Network Topology

```
Internet
    │
    ▼
Spectrum Router (SAX2V1S)
WAN: 68.184.198.204  /  LAN: 192.168.1.1
    │
    ├── 192.168.1.x  (Main LAN)
    │   ├── gaming-pc       192.168.1.62
    │   └── optiplex-fw     192.168.1.189
    │         └─ re0 alias  192.168.1.76  (legacy NAS IP; rdr'd to 192.168.100.76)
    │
    ▼
┌──────────────────────────────────────────┐
│  OpenBSD Firewall (optiplex-fw)          │
│  Hardware: Dell Optiplex 3040 MT         │
│  OS: OpenBSD 7.9                         │
│  ext_if re0: 192.168.1.189 (Main LAN)   │
│           +  192.168.1.76/32 alias       │
│  int_if em0: 192.168.100.1 (Server LAN) │
└──────────────────────────────────────────┘
    │
    ├── 192.168.100.x  (Server LAN)
    │   ├── optiplex-nas    192.168.100.76
    │   └── mini-server     192.168.100.103
```

**optiplex-nas is behind the firewall** (moved off the Main LAN 2026-07-15). Its old
address `192.168.1.76` lives on as a `/32` alias on the firewall's `re0`, with pf
`rdr-to` rules forwarding the exposed services to `192.168.100.76` so LAN/VPN clients
that still know the NAS as `.76` keep working with no client changes. See
[NAS-behind-firewall specifics](#nas-behind-firewall-specifics) below.

### SSH Access

```bash
ssh lando@192.168.1.189   # direct
ssh fw                     # via ~/.ssh/config alias on gaming-pc
```

### Key PF Commands

```bash
doas pfctl -f /etc/pf.conf   # reload rules after editing
doas pfctl -sr                # show active rules
doas pfctl -ss                # show state table
doas pfctl -si                # statistics
```

### Adding a Port Forward

1. **Router**: add forward in mySpectrum app → 192.168.1.189
2. **optiplex-fw** `/etc/pf.conf`: add rdr-to rule, then `doas pfctl -f /etc/pf.conf`
3. Commit change to openbsd-dotfiles repo

### WireGuard VPN

- **Listen port**: 51822 (UDP) — forwarded directly by the Spectrum router to 192.168.1.189
- **VPN subnet**: 10.10.0.0/24 — server is 10.10.0.1
- **Server public key**: `Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=`
- **Server private key**: `/etc/wireguard/server_private.key` — NOT tracked in any repo
- **Interface config**: `/etc/hostname.wg0`

#### Peers

| Name | VPN IP | Access | Notes |
|------|--------|--------|-------|
| Lando (gaming-pc) | 10.10.0.2 | Full | |
| Lando (Android) | 10.10.0.3 | Full | full tunnel (0.0.0.0/0) |
| Chris | 10.10.0.4 | Restricted | NAS only (192.168.1.76) |
| Blaney | 10.10.0.5 | Restricted | NAS only |
| Emily | 10.10.0.6 | Restricted | NAS only |
| Russell | 10.10.0.7 | Restricted | NAS only |
| Cmoore | 10.10.0.8 | Restricted | NAS only |
| Alex | 10.10.0.10 | Restricted | NAS only |
| Lando (gaming-pc wg-nas) | 10.10.0.11 | NAS Samba only | Dedicated LAN tunnel for encrypted SMB; allowed-ips 192.168.100.76/32. See `nasViaLanWg` in `hosts/gaming-pc/default.nix`. |

Restricted peers can reach (all via the legacy 192.168.1.76 alias, rdr'd to the NAS at 192.168.100.76): Jellyfin (8096), Jellyseerr (5055), article2pod/reader (8100) on the NAS, and game-control dashboard (8080) + Vaultwarden (8222) on mini-server. Transmission is no longer exposed to restricted peers. All other traffic blocked via `<restricted_peers>` PF table.

### NAS-behind-firewall specifics

optiplex-nas is on the server subnet at **192.168.100.76**. Its NixOS static IP is set
in `hosts/optiplex-nas/default.nix` (`192.168.100.76` / gw `192.168.100.1`).

**Legacy `192.168.1.76` alias + rdr** (in `/etc/pf.conf` on optiplex-fw): the firewall
holds `192.168.1.76/32` as an alias on `re0` and redirects to the NAS:
- **From the Main LAN (`re0`)**: TCP `80` (nginx reverse proxy — serves all the
  `*.lan` domains by Host header), `8096` (Jellyfin), `5055` (Jellyseerr), `5000`
  (nix binary cache), and `53` (DNS, tcp+udp) → `192.168.100.76`.
- **From WireGuard (`wg0`)**: full peers get the same `53` (DNS) and `80` (reverse
  proxy → `*.lan`) as the LAN, plus `445`/`139` (Samba), `9091` (Transmission), and the
  service ports; `8100` (article2pod) is redirected for all peers. Restricted peers are
  then filtered by the `<restricted_peers>` allow-list (they use `1.1.1.1` for DNS and
  reach services by direct IP, so they don't need 53/80).
- **SSH to the NAS is NOT forwarded on `.76`** — port 22 to `192.168.1.76` hits the
  firewall itself. Reach the NAS via jump host: `ssh -J lando@192.168.1.189 lando@192.168.100.76`
  (or over the wg-nas tunnel from gaming-pc).

**VPN peer addressing (which NAS address a client should use)** — the legacy `.76`
redirect only helps a peer if that peer's WireGuard **`AllowedIPs`** actually routes
`192.168.1.76` into the tunnel:
- **Restricted peers** (Chris, Blaney, …) are generated with `AllowedIPs = 192.168.1.76/32`
  (see `add-vpn-client.sh`), so they route only `.76` and reach NAS services via the
  legacy alias + rdr. Correct address for them: **`192.168.1.76`**.
- **Full peers** whose tunnel routes the **server subnet** (`192.168.100.0/24`) but *not*
  the old Main LAN (`192.168.1.0/24`) — e.g. Lando's phone — must use the NAS's real
  address **`192.168.100.76`** (the `.76` alias won't route for them). To make the legacy
  `.76` work for such a peer instead, add `192.168.1.0/24` to that peer's client-side
  `AllowedIPs`. gaming-pc sidesteps this entirely via the dedicated `wg-nas` tunnel.

**DNS**: the NAS runs Unbound (`homelab.dns.enable`) as the LAN resolver — a split-horizon
setup that serves the `.lan` zone locally and forwards everything else to Cloudflare/Quad9
over DoT. The `.76`→NAS port-53 rdr routes queries aimed at the legacy IP to it.

**The Spectrum router does NOT hand out `192.168.1.76` as the DHCP DNS server** — it points
DHCP clients at itself (`192.168.1.1`), which knows nothing about `.lan`. NixOS hosts resolve
`.lan` only because their resolver is hardcoded to `192.168.1.76` in config (`localDns.server`
/ `networking.nameservers`); `mini-server` (server subnet) points directly at `192.168.100.76`.
Plain DHCP devices (phones, guests, IoT) therefore **cannot resolve `.lan` out of the box**.
The fix used is **per-device static DNS = `192.168.1.76` with NO public secondary** (a public
DNS2 like `8.8.8.8` poisons `.lan`, since clients race the two resolvers and accept the public
NXDOMAIN). A LAN-wide fix (router DHCP → `.76`) was rejected: it makes the NAS a single point
of failure for all internet DNS and routes every device's lookups through the NAS's Mullvad
full-tunnel exit.

**Mullvad return-route gotcha** (`hosts/optiplex-nas/default.nix`): the NAS runs Mullvad
as a full-tunnel VPN, whose policy routing sends any subnet **not in the main routing
table** into the tunnel. Replies to Main-LAN clients (`192.168.1.0/24`) and WireGuard
peers (`10.10.0.0/24`) would vanish into Mullvad, so explicit main-table routes send
that return traffic back through the firewall:
```nix
networking.interfaces.enp0s31f6.ipv4.routes = [
  { address = "192.168.1.0"; prefixLength = 24; via = "192.168.100.1"; }
  { address = "10.10.0.0";   prefixLength = 24; via = "192.168.100.1"; }
];
```
Without these, DNS/Jellyfin/Samba/nix-cache all break for anything not on the server
subnet — the SYN arrives at the NAS but the reply disappears into the VPN.

**gaming-pc Samba over wg-nas**: gaming-pc mounts the NAS Samba share (`/mnt/nas`) over a
dedicated LAN WireGuard tunnel (`wg-nas`, peer `10.10.0.11`, allowed-ips
`192.168.100.76/32`) so SMB is never in cleartext on the LAN. Gated by `nasViaLanWg` in
`hosts/gaming-pc/default.nix`; the private key is in `secrets/gaming-pc.yaml` as
`wg-nas-private-key`. The `rebuild` cache-push (`modules/nixos/common/commands.nix`)
pushes to the NAS at `192.168.100.76` (reachable via this tunnel / directly from the
server subnet).

#### Adding a New Peer

Run `~/openbsd-dotfiles/scripts/add-vpn-client.sh <name> [--jellyfin]` from optiplex-fw. The script:
- Auto-detects next available VPN IP
- Generates keypair, adds to live wg0 and hostname.wg0, updates pf.conf restricted_peers table
- Optionally creates a Jellyfin user
- Generates a QR code (if `qrencode` installed) and saves client config to `~/openbsd-dotfiles/wireguard-clients/`

After running: commit the updated configs in openbsd-dotfiles, then add the new row to the Peers table above.

#### WireGuard Management Commands

```bash
ssh fw
doas wg show              # status and peer handshake times
doas wg show wg0 dump     # detailed peer info
```

#### Hairpin NAT Limitation

The Spectrum router does not support hairpin NAT. Gaming-pc works around this with a static route: `68.184.198.204/32 via 192.168.1.189` (configured in `hosts/gaming-pc/default.nix` via `networking.networkmanager.dispatcherScripts`). OpenBSD has matching rdr-to rules for this traffic.

### Wake-on-LAN

```bash
ssh fw
wake-gaming    # wakes gaming-pc (10:ff:e0:36:db:4b on 192.168.1.255)
wake-optiplex  # wakes optiplex (e4:b9:7a:ed:67:8c on 192.168.100.255)
```

Aliases are in `~/.kshrc` on optiplex-fw. Requires `customConfig.networking.wakeOnLan` enabled in each NixOS host config.

## PRIMARY RULES: Making and Committing Changes

**CRITICAL**: Follow this exact order — commit only comes AFTER verify:

1. **Branch** — create a feature/fix branch
2. **Edit** configuration files
3. **`sudo chown -R lando:users /home/lando/nixos-config`** ← always do this before rebuild
4. **`rebuild`** ← REQUIRED before committing
5. **Verify** the changes work correctly (open the app, check the setting, confirm the behavior)
6. **Commit** — only after steps 4 and 5 succeed
7. **PR** — only after step 6; do not open a PR before the change is verified working on the current host

**Exception**: Changes that can only be tested on a different host (different machine, hardware, or display required) skip steps 4–5 locally. Instead: eval-check → commit → PR (note in-person testing needed) → merge after confirmed on target.

Never commit to main before rebuilding and verifying. This applies even to "obviously correct" changes.

The `rebuild` command automatically detects the current host. **Never manually specify the hostname.**

For testing changes without permanently switching:

```bash
sudo nixos-rebuild test --flake /home/lando/nixos-config#$(hostname) --impure
```

## File Permissions

After making edits, files may end up with incorrect ownership. Fix with:

```bash
sudo chown -R lando:users /home/lando/nixos-config
```

Note: Do NOT use `sudo chown -R $USER:users ~/nixos-config` — when running as sudo, `$USER` and `~` both expand to `root`.

## Host-Specific Guidelines

### blaney-pc

When running on the `blaney-pc` host, apply these additional guidelines:

**User Context**: insideabush has no Linux or Nix technical knowledge. He is not able to make technical or architectural decisions.
- If he asks to learn something, explain it simply and concisely — go deeper only if he probes
- Otherwise: fix the issue or implement the feature — keep communication brief, clear, and directive
- He CAN and SHOULD make UX/visual decisions: colors, layout, what something looks like, what a feature does from a user perspective

**Decision Authority**:
- **Claude decides autonomously**: module structure, NixOS options, which files to edit, how to architect changes, naming conventions — anything technical. Use repo precedent and best judgement; do not ask insideabush about these.
- **insideabush decides**: visual appearance, user-facing behavior, feature scope and direction
- **Bug fixes** → act immediately with minimal explanation; only ask insideabush if the problem is genuinely ambiguous
- **Feature requests** → ask what he wants it to look/feel like to establish UX direction, then execute independently

**Autonomy — Do Everything Possible**:
- Run `rebuild`, copy files, run commands — anything within Claude's capability that doesn't require physical user action
- **Never ask insideabush to run a command Claude can run itself**
- Do not ask for confirmation on technical choices; make them and briefly note what was done
- Always `chown` and `rebuild` as part of your workflow; don't hand these off to insideabush

**Communication**:
- For features: ask about UX direction, then execute silently
- For bugs: diagnose and fix; give insideabush clear "does this look right?" checkpoints
- Give next steps as plain, one-sentence instructions (e.g. "Tell me if the wallpaper changed after it rebuilds")
- Never use technical jargon without immediately explaining it in plain terms

**Branch Naming Convention (STRICT)**:
- All branches for insideabush's work MUST use the prefix `blaney/`
  - Examples: `blaney/feat-party-mode`, `blaney/fix-wifi-issue`
- This prefix distinguishes insideabush's branches from lando's branches — do not deviate from it
- When continuing prior work, reuse the existing `blaney/` branch if still relevant; check `git branch -a` first

**Git Workflow (STRICT)**:
- **NEVER push or commit directly to `main`** — always use a `blaney/` branch
- **NEVER merge into any branch that does not start with `blaney/`** — this includes `main` and all branches created by lando or his Claude sessions
- insideabush's Claude sessions CAN: create new `blaney/` branches, push to those branches, merge other existing branches INTO a `blaney/` branch
- insideabush's Claude sessions CANNOT: push to `main`, push to any non-`blaney/` branch, merge a `blaney/` branch into a non-`blaney/` branch
- When insideabush confirms a feature is working and acceptable: open a PR from the `blaney/` branch to `main` via `gh pr create`
- **Never merge the PR** — lando (`landonreekstin`) merges all PRs from blaney-pc

**Safety**:
- Always use `nixos-rebuild test` before `rebuild` for significant changes, so insideabush can verify before permanently switching
- Keep changes focused and minimal

## Task Workflow (TASKS.md)

A `TASKS.md` file in the repo root contains a prioritized list of pending work. **Only work on tasks when explicitly asked** — do not autonomously pick up tasks between sessions.

When asked to work on tasks, follow this workflow for each task:

1. **Branch** — create a feature branch (`feat/`, `fix/`, etc.) from `main`
2. **Implement** — make the changes
3. **Eval-check** — verify the config evaluates for all hosts (can't run `sudo nixos-rebuild` without a terminal):
   ```bash
   NIXPKGS_ALLOW_UNFREE=1 nix eval --impure .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
   ```
   For changes to shared modules, check **all hosts**:
   ```bash
   for host in gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas mini-server; do
     echo -n "$host: " && NIXPKGS_ALLOW_UNFREE=1 nix eval --impure ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" 2>&1 | tail -1
   done
   ```
   CI (GitHub Actions) also runs this automatically on every PR.
4. **Commit and push** the branch
5. **Open a PR** via `gh pr create`
6. **Check off** the task in `TASKS.md` on `main` (or mark it as pending in-person testing if it needs a reboot/display to verify)

Tasks that require physical machine testing (reboot, display, hardware) should be noted in TASKS.md as `*(PR open — needs in-person test)*` and merged when the user confirms they work.

**Always update TASKS.md after completing a task** — mark it `[x]` and commit the change to `main`, even if it was verified outside the formal task workflow (e.g. a fix done mid-conversation that corresponds to a listed task).

## Companion Repositories

### hyprland-keys

Source: `github:landonreekstin/hyprland-keys`
Package: `modules/home-manager/scripts/hyprland-keys.nix`

The package is pinned via `fetchFromGitHub`. After pushing changes to the
hyprland-keys repo, update the pin here:

```bash
# Run from inside nixos-config
SHA=$(cd /home/lando/hyprland-keys && git rev-parse HEAD)
HASH=$(nix-prefetch-url --unpack \
  https://github.com/landonreekstin/hyprland-keys/archive/${SHA}.tar.gz 2>/dev/null \
  | xargs -I{} nix hash convert --hash-algo sha256 --to sri {})
echo "rev = \"$SHA\";"
echo "hash = \"$HASH\";"
```

Then update `rev` and `hash` in `modules/home-manager/scripts/hyprland-keys.nix`,
eval-check all hosts, rebuild on gaming-pc to verify, then commit and push.

## Notes

- **CRITICAL**: Always use the `rebuild` command, never manually specify `--flake .#<hostname>`. Each host has different users and hardware - applying the wrong host config can remove user accounts, break authentication, and cause boot failures.
- Always use the `--impure` flag with nixos-rebuild for this configuration
- The `customConfig` system requires understanding the options defined in `common-options.nix`
- Host configurations should primarily set `customConfig` values rather than raw NixOS options
- Unstable packages can be selectively enabled via `customConfig.packages.unstable-override`
- Functional vs theme paradigm for wayland components