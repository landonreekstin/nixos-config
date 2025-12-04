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

## Working with Themes

### Plasma Themes
- `windows7` / `windows7-alt` - Complete Windows 7 recreation with custom plasmoids
- `bigsur` - macOS Big Sur appearance
- `aerothemeplasma` - Base Aero theme system

Theme configuration is set via `customConfig.homeManager.themes.kde`.

### Custom SDDM Themes
Configure via `customConfig.desktop.displayManager.sddm.customTheme` with wallpaper, colors, and styling options.

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

### Making Changes
1. Edit configuration files in your local `~/nixos-config` clone
2. Use `rebuild` to test changes
3. Commit and push changes when satisfied
4. Other machines can `sync` to pull updates

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

## File Permissions

After making edits to files in the repository, some files may end up with incorrect ownership. To fix permissions and restore proper ownership to the user:

```bash
sudo chown -R $USER:users ~/nixos-config
```

This command should be run after editing configuration files to ensure the user can manually edit and save files in their editor.

## Notes

- Always use the `--impure` flag with nixos-rebuild for this configuration
- The `customConfig` system requires understanding the options defined in `common-options.nix`
- Host configurations should primarily set `customConfig` values rather than raw NixOS options
- Unstable packages can be selectively enabled via `customConfig.packages.unstable-override`
- **IMPORTANT**: After making file edits, run `sudo chown -R $USER:users ~/nixos-config` to restore proper file ownership