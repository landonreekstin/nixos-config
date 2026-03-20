# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS configuration flake that manages multiple hosts with shared modules. The configuration uses a custom options system (`customConfig`) to provide type-safe, declarative configuration across all hosts.

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

### Hardware Configurations
Hardware configs are auto-generated during installation and should not be manually edited. They're stored per-host in `hosts/<hostname>/hardware-configuration.nix`.

## Installation

Use `scripts/install-new-host.sh` for fresh installations. This script:
1. Partitions disks using Disko configurations
2. Generates hardware configuration
3. Installs NixOS with the flake
4. Sets up user passwords

After first boot, run `post-install` to complete setup and establish Git access.

## Homelab Services

Available via `customConfig.homelab`:
- Jellyfin media server
- Samba file sharing
- *arr stack (Radarr, Sonarr, Prowlarr, Bazarr)

## PRIMARY RULES: Making and Committing Changes

**CRITICAL**: Follow this exact order — commit only comes AFTER verify:

1. **Branch** — create a feature/fix branch
2. **Edit** configuration files
3. **`sudo chown -R lando:users /home/lando/nixos-config`** ← always do this before rebuild
4. **`rebuild`** ← REQUIRED before committing
5. **Verify** the changes work correctly (open the app, check the setting, confirm the behavior)
6. **Commit and PR** — only after steps 4 and 5 succeed

**Exception**: Changes that can only be tested on a different host (different machine, hardware, or display required) skip steps 4–5 locally. Instead: eval-check → commit → PR → note that in-person testing is needed → merge after confirmed on target.

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

**User Context**: This machine is used by a user who is new to NixOS and this configuration system. They are interested in experimenting and learning through hands-on exploration.

**Communication Style**:
- Provide clear explanations of what changes will do before making them
- Use plain language when describing technical concepts
- Offer context about why certain approaches are recommended
- Be patient with questions that may seem basic

**Verification and Clarification**:
- Ask clarifying questions when requests are ambiguous or could be interpreted multiple ways
- Verify understanding of the user's intent before making significant changes
- If the user describes a problem or system state that seems inconsistent, gently ask for more details rather than assuming
- Double-check terminology - the user may use imprecise terms, so confirm what they mean

**Git and Version Control**:
- **Do not make git commits unless explicitly instructed** - the user may want to review changes first or have the repository owner handle commits
- Explain what files were changed so the user can communicate this to others if needed

**Decision Making**:
- For architectural or significant design decisions, explain the options and trade-offs rather than making unilateral choices
- Prefer conservative, well-tested approaches over experimental ones
- When in doubt, suggest the user consult with the repository owner for complex changes

**Safety**:
- Always use `nixos-rebuild test` first for significant changes, allowing the user to verify before switching permanently
- Clearly warn about any changes that could affect system stability or boot
- Keep changes focused and minimal to reduce the chance of issues

**Git Workflow (STRICT)**:
- **Always create a feature branch** for any changes — never commit directly to `main`
- **Always open a PR** via `gh pr create` after pushing the branch
- **Never merge a PR** from this host or when the git user is `insideabush` — merging must be done by the repository owner (`landonreekstin`) on another machine
- This applies regardless of how trivial the change seems

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
   for host in gaming-pc optiplex blaney-pc justus-pc asus-laptop asus-m15 atl-mini-pc optiplex-nas; do
     echo -n "$host: " && NIXPKGS_ALLOW_UNFREE=1 nix eval --impure ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" 2>&1 | tail -1
   done
   ```
   CI (GitHub Actions) also runs this automatically on every PR.
4. **Commit and push** the branch
5. **Open a PR** via `gh pr create`
6. **Check off** the task in `TASKS.md` on `main` (or mark it as pending in-person testing if it needs a reboot/display to verify)

Tasks that require physical machine testing (reboot, display, hardware) should be noted in TASKS.md as `*(PR open — needs in-person test)*` and merged when the user confirms they work.

**Always update TASKS.md after completing a task** — mark it `[x]` and commit the change to `main`, even if it was verified outside the formal task workflow (e.g. a fix done mid-conversation that corresponds to a listed task).

## Notes

- **CRITICAL**: Always use the `rebuild` command, never manually specify `--flake .#<hostname>`. Each host has different users and hardware - applying the wrong host config can remove user accounts, break authentication, and cause boot failures.
- Always use the `--impure` flag with nixos-rebuild for this configuration
- The `customConfig` system requires understanding the options defined in `common-options.nix`
- Host configurations should primarily set `customConfig` values rather than raw NixOS options
- Unstable packages can be selectively enabled via `customConfig.packages.unstable-override`
- Functional vs theme paradigm for wayland components