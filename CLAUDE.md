# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS configuration flake that manages multiple hosts with shared modules. The configuration uses a custom options system (`customConfig`) to provide type-safe, declarative configuration across all hosts.

## Development Commands

### System Management
- `rebuild` - Rebuild the current host configuration using the local flake
- `sync` - Pull latest changes from the remote repository (handles merge conflicts)
- `update` - Update flake inputs (requires `updateCmdPermission` enabled)
- `upgrade` - Update flake inputs and rebuild system in one command
- `post-install` - Complete initial setup after fresh NixOS installation

### NixOS Rebuild Commands
The primary command for applying configuration changes:
```bash
sudo nixos-rebuild switch --flake ~/nixos-config#<hostname> --impure
```

For testing changes without switching:
```bash
sudo nixos-rebuild test --flake ~/nixos-config#<hostname> --impure
```

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
2. Use `rebuild` to test changes
3. Commit and push changes when satisfied
4. Other machines can `sync` to pull updates

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

## PRIMARY RULES: After Making Changes

**CRITICAL**: These steps must be followed after ANY configuration changes:

### 1. Restore File Ownership (REQUIRED)
**ALWAYS run this command immediately after editing files:**

```bash
sudo chown -R $USER:users ~/nixos-config
```

This prevents permission issues and ensures files remain editable. **This must be done before rebuilding.**

### 2. Rebuild System (REQUIRED)
**ALWAYS rebuild to apply configuration changes:**

```bash
rebuild
```

This command rebuilds the current host configuration using the local flake. 

### 3. Test Changes (Optional)
For testing changes without permanently switching, use:

```bash
sudo nixos-rebuild test --flake ~/nixos-config#<hostname> --impure
```

### Complete Workflow:
1. **Edit configuration files**
2. **`sudo chown -R $USER:users ~/nixos-config`** ← CRITICAL
3. **`rebuild`** ← REQUIRED
4. **Verify changes work correctly**

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

## Notes

- Always use the `--impure` flag with nixos-rebuild for this configuration
- The `customConfig` system requires understanding the options defined in `common-options.nix`
- Host configurations should primarily set `customConfig` values rather than raw NixOS options
- Unstable packages can be selectively enabled via `customConfig.packages.unstable-override`
- Functional vs theme paradigm for wayland components