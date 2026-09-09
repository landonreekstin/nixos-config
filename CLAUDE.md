# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS configuration flake that manages multiple hosts with shared modules. The configuration uses a custom options system (`customConfig`) to provide type-safe, declarative configuration across all hosts.

## Reference Docs

`CLAUDE.md` holds the rules and lookups needed for *everyday* work. Deeper material lives
in `docs/` — read the matching file when the task calls for it:

| Doc | Read it when |
|---|---|
| [docs/architecture.md](docs/architecture.md) | adding a host file, deciding where an option is *declared*, or refactoring/moving config (incl. the no-op proof recipes) |
| [docs/theming.md](docs/theming.md) | Plasma / SDDM / Hyprland themes, or any `modules/home-manager/themes/*` work |
| [docs/networking.md](docs/networking.md) | the OpenBSD firewall, WireGuard peers, port forwards, `.lan` DNS, NAS addressing, wake-on-LAN |
| [docs/flake-updates.md](docs/flake-updates.md) | blocking / fixing / explaining a weekly `update/*` PR, or beta-host tracking |
| [docs/test-vms-and-ci.md](docs/test-vms-and-ci.md) | using `vm-sandbox` / `vm-blaney`, or changing the CI workflow / NAS runner |
| [docs/remote-xfce-rdp.md](docs/remote-xfce-rdp.md) | XFCE-over-xrdp work, or a `rebuild` that didn't visibly change a live XFCE session |
| [docs/installation.md](docs/installation.md) | deploying a new host or re-installing an existing one |
| [docs/hosts/blaney-pc.md](docs/hosts/blaney-pc.md) | the session is on `blaney-pc` (user `insideabush`), or writing a `docs/runbooks/blaney/` task |
| [docs/companion-repos.md](docs/companion-repos.md) | bumping the pin of a package sourced from another of our repos |

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

#### blaney-pc-only commands (gated to the `insideabush` user)
Defined in `modules/nixos/common/commands.nix` under `lib.optionals (cfg.user.name == "insideabush")`:
- `branch-switch` - Numbered-menu branch picker: fetches, lists all branches (main first), stashes current changes (tagged with their source branch), checks out the chosen branch, offers to restore a stash saved for that branch, then rebuilds. On rebuild failure it points the user at `smart-rebuild` / `claude-rebuild-failed`.
- `blaney-todo` - Numbered-menu task picker: fetches `origin/main`, lists the runbooks in `docs/runbooks/blaney/`, and launches `claude` on the chosen one with a blaney-pc preface prompt. See [Runbooks as blaney-pc tasks](docs/hosts/blaney-pc.md#runbooks-as-blaney-pc-tasks).
- `blaney-help` - Prints a curated one-line cheat-sheet of the commands insideabush uses. **This is the user-facing command index — keep it in sync when adding/removing blaney commands.**

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
- `hosts/` - Host-specific configurations: a `default.nix` importer, `hardware-configuration.nix`, and one file per config domain (see [Host File Layout](#host-file-layout))
- `modules/nixos/` - System-level NixOS modules
- `modules/home-manager/` - User-level Home Manager modules


### Host File Layout

A host directory mirrors `modules/nixos/`: one file per domain, `default.nix` is an
**importer only**, and each top-level `customConfig` attribute is owned by exactly one
file per host. A host only creates the files it needs.

| File | Owns `customConfig.*` |
|---|---|
| `vars.nix` | *(not a module — a plain attrset of host flags `import`ed by the others)* |
| `system.nix` | `user`, `system`, `bootloader` (+ `boot.loader.*`, host-wide `sops.*`) |
| `desktop.nix` | `desktop` (+ `services.xserver`/`displayManager`/`xrdp`) |
| `hardware.nix` | `hardware` (+ `hardware.nvidia.open`, initrd modules, blacklists, `keyd`) |
| `apps.nix` | `apps`, `programs`, `packages` (+ `programs.*`, `services.flatpak`) |
| `home.nix` | `homeManager` (+ the `home-manager = lib.mkIf …` block) |
| `networking.nix` | `networking`, `services` (+ firewall/hosts/routes/wg-quick) |
| `homelab.nix` | `homelab` (+ homelab-adjacent units) |
| `profiles.nix` | `profiles` |

Keep the directory **flat** (host files use repo-relative paths), put feature-specific
`sops.secrets.<x>` next to the feature that consumes it, and remember a `let` binding
cannot span files — shared flags go in `vars.nix`.

**Before moving anything between these files, read
[docs/architecture.md](docs/architecture.md)** — it carries the full table with the raw
NixOS config each file also holds, the list-merging/ordering gotchas, and the drvPath
proof that a refactor is a no-op.

### Module Option Layout

There is no central options file. **An option block is declared by the module that owns
the feature it configures** — `homelab/jellyfin.nix` declares `customConfig.homelab.jellyfin`
*and* the `config` implementing it. Options that are cross-cutting, home-manager-only, or
split across several modules go in that domain's `options.nix` instead.

| Domain | Declared by |
|---|---|
| `homelab.*` | the matching `homelab/<service>.nix`; only `reverseProxy` in `homelab/options.nix` |
| `desktop.*` | `desktop/{kde,hyprland,xrdp,display-manager,custom-sddm-theme}.nix`; the rest in `desktop/options.nix` |
| `hardware.*` | `hardware/{nvidia,peripherals}.nix`; the rest in `hardware/options.nix` |
| `services.*` | `services/{ssh,vscode-server,wireguard-client,wireguard-server}.nix`; `autoUpdate` in `common/auto-update.nix` |
| `profiles.*` | `profiles/gaming.nix` and each `development/*.nix` — no `options.nix` |
| `programs.*` | `programs/{partydeck,claude-code}.nix`; `firefox`/`flatpak` in `programs/options.nix` |
| `apps.*` | `apps/programs.nix` (registry + `mkAppRole`), `apps/xdg-defaults.nix` (MIME) |
| `bootloader`, `networking`, `homeManager` | `common/{bootloader,networking,home-manager}.nix` |
| `user`, `system`, `packages` | `common/options.nix` |

Fallback for a namespace with no owning module: `customConfig.<X>` → `modules/nixos/<X>/`
if that directory exists, else `common/`. Add every new `options.nix` to its domain's
`default.nix` imports.

**Before moving a declaration, read [docs/architecture.md](docs/architecture.md)** — Nix
merges duplicate attrset literals silently (that is how options ended up declared twice
before), a module with `options` cannot use shorthand config, and the doc has the
`customConfig`-fixpoint check that proves the move changed nothing.

### Configuration System
All configuration is managed through the `customConfig` option set, declared per-module (see [Module Option Layout](#module-option-layout) and [docs/architecture.md](docs/architecture.md)). This provides:
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

Theme selection is `customConfig.homeManager.themes.{kde,hyprland}`; custom SDDM styling
is `customConfig.desktop.displayManager.sddm.customTheme`.

**Wayland components follow a strict functional-vs-theme split**: `*/functional.nix` is
always active and owns keybinds, monitor/input config, services and packages (with
`mkDefault`); `themes/*/` is conditional and owns *only* visual styling (with `mkForce`).
Themes never duplicate functional settings.

Available themes, the full paradigm with examples, and the per-theme details are in
**[docs/theming.md](docs/theming.md)** — read it before touching any theme module.

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

### Hardware Configurations
Hardware configs are auto-generated during installation and should not be manually edited. They're stored per-host in `hosts/<hostname>/hardware-configuration.nix`.

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


## Automated Weekly Flake Updates

`optiplex-nas` runs a flake-updater every Monday at 03:00: it creates `update/YYYY-WNN`,
builds all hosts, and opens a PR. **gaming-pc** (`betaTesterHost = true`) auto-tracks the
latest `update/*` branch on `sync`, soaking the update a week early; the following
Monday's run auto-merges the prior PR unless it carries the `update-blocked` label.

For Claude, the two common requests:
- **"approve the update" / "let it merge"** — do nothing. The NAS auto-merges on the next
  Monday run. Manually running `gh pr merge` is wrong and bypasses the soak period.
- **"block the update"** — `gh pr edit <PR> --repo landonreekstin/nixos-config --add-label "update-blocked"`
  (find it with `gh pr list --label flake-update`).

Fixing an update branch, rolling back gaming-pc, and manual triggering are in
**[docs/flake-updates.md](docs/flake-updates.md)**.

## Test VMs, Installation, and Remote XFCE

Three topics that only matter when you are actively doing them:

- **Test VMs & CI** — `testvm sandbox` / `testvm blaney` build throwaway QEMU hosts for
  desktop/theme software-config work (they cannot validate GPU/driver behaviour). CI has
  an `evaluate` job for all hosts plus a gated `build` job on the NAS runner.
  → **[docs/test-vms-and-ci.md](docs/test-vms-and-ci.md)**
- **Installation** — remote deploy via `scripts/deploy-host.sh` (nixos-anywhere), the
  on-target fallback, and the new-host checklist. → **[docs/installation.md](docs/installation.md)**
- **Remote XFCE via RDP (gaming-pc)** — SSH-tunnelled xrdp for desktop work from Windows,
  plus the XFCE daemon-cache traps (`win7-xfce-refresh`).
  → **[docs/remote-xfce-rdp.md](docs/remote-xfce-rdp.md)**

## Homelab Services

Available via `customConfig.homelab`:
- Jellyfin media server
- Samba file sharing
- *arr stack (Radarr, Sonarr, Prowlarr, Bazarr)

## Networking, Firewall, and VPN

The homelab sits behind **optiplex-fw**, an OpenBSD 7.9 box that is the only non-NixOS
host here (config tracked in the private `openbsd-dotfiles` repo, live files are the
source of truth). Main LAN `192.168.1.0/24` → firewall `re0 192.168.1.189` → server LAN
`192.168.100.0/24` (`optiplex-nas` `.76`, `mini-server` `.103`). WireGuard listens on
UDP 51822, VPN subnet `10.10.0.0/24`.

Two things that bite constantly and are worth knowing up front:
- **The NAS's legacy `192.168.1.76`** is a `/32` alias on the firewall, `rdr-to`'d to
  `192.168.100.76`. SSH is *not* forwarded on it — reach the NAS with
  `ssh -J lando@192.168.1.189 lando@192.168.100.76`.
- **The NAS runs Mullvad as a full tunnel**, so any subnet missing from its main routing
  table disappears into the VPN. Explicit routes for `192.168.1.0/24` and `10.10.0.0/24`
  in `hosts/optiplex-nas/networking.nix` are what keep DNS/Jellyfin/Samba working for
  everything off the server subnet.

Everything else — the full topology, pf commands, port forwards, the peer table and
`add-vpn-client.sh`, `.lan` split-horizon DNS, VPN peer addressing rules, hairpin NAT,
and wake-on-LAN — is in **[docs/networking.md](docs/networking.md)**.

## PRIMARY RULES: Making and Committing Changes

**CRITICAL**: Follow this exact order — commit only comes AFTER verify:

1. **Branch** — create a feature/fix branch
2. **Edit** configuration files
3. **`sudo chown -R lando:users /home/lando/nixos-config`** ← always do this before rebuild
4. **`rebuild`** ← REQUIRED before committing
5. **Verify** the changes work correctly (open the app, check the setting, confirm the behavior)
6. **Commit** — only after steps 4 and 5 succeed
7. **PR** — only after step 6; do not open a PR before the change is verified working on the current host

**Exception**: changes that can only be tested on a different host (different machine,
hardware, or display required) skip steps 4–5 locally. Instead: eval-check → commit → PR
(note in-person testing needed) → merge after confirmed on target.

**Never commit to main before rebuilding and verifying**, even for "obviously correct"
changes. `rebuild` detects the current host — **never manually specify the hostname**. To
activate without making it the boot default:

```bash
sudo nixos-rebuild test --flake /home/lando/nixos-config#$(hostname) --impure
```

### Branching strategy

- **Direct to main**: documentation (`docs`), minor tweaks (`tweak`), and simple additions
  like a package — after verification.
- **Feature/PR branches**: anything being developed on this machine (rebuild and verify on
  the branch, then PR), and anything only testable elsewhere (note in the PR that in-person
  testing on the target is needed).
- **Never commit broken changes to main.** Merge only once rebuilt, tested, and verified.

**Do not open a PR until the change has been tested on the machine currently being
developed on.** If Claude Code is running on `asus-laptop` and the change targets
`asus-laptop`, `rebuild` and verify *before* creating the PR — not after. PRs represent
verified, working changes, not speculative ones.

### File permissions

After edits, files may end up owned by root. Fix with the explicit path:

```bash
sudo chown -R lando:users /home/lando/nixos-config
```

Do NOT use `sudo chown -R $USER:users ~/nixos-config` — under sudo, `$USER` and `~` both
expand to `root`, making it a no-op or targeting the wrong path.

## Host-Specific Guidelines

### blaney-pc

When the session is running on `blaney-pc` (user `insideabush`), **read
[docs/hosts/blaney-pc.md](docs/hosts/blaney-pc.md) and follow it** — it overrides the
general workflow above. The rules in brief, none of which are optional:

- insideabush is non-technical: Claude makes every technical/architectural decision;
  he decides visual appearance and user-facing behaviour.
- Do everything yourself (`chown`, `rebuild`, commands) — never hand a command to him.
- **All branches use the `blaney/` prefix.** Never commit or push to `main` or to any
  non-`blaney/` branch, and never merge a `blaney/` branch anywhere — open a PR and let
  lando merge it.
- `docs/runbooks/blaney/*.md` is his task queue, surfaced by the `blaney-todo` command.

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

Some packages here are pinned to other repos of ours (e.g. `hyprland-keys`, pinned via
`fetchFromGitHub` in `modules/home-manager/scripts/hyprland-keys.nix`). The rev/hash
bump procedure is in **[docs/companion-repos.md](docs/companion-repos.md)**.

## Notes

- **CRITICAL**: Always use the `rebuild` command, never manually specify `--flake .#<hostname>`. Each host has different users and hardware - applying the wrong host config can remove user accounts, break authentication, and cause boot failures.
- Always use the `--impure` flag with nixos-rebuild for this configuration
- The `customConfig` system requires understanding the options declared per-module (see [Module Option Layout](#module-option-layout) and [docs/architecture.md](docs/architecture.md))
- Host configurations should primarily set `customConfig` values rather than raw NixOS options
- Unstable packages can be selectively enabled via `customConfig.packages.unstable-override`
