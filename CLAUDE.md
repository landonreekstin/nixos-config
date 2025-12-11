# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS configuration flake that manages multiple hosts with shared modules. The configuration uses a custom options system (`customConfig`) to provide type-safe, declarative configuration across all hosts.

**Note:** This is the `dev-homelab-nas` branch, which is a simplified version focused on homelab and NAS functionality. Many desktop-focused features present in other branches have been removed or are not available here.

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
- `customConfig.networking` - Network configuration (static IP, NetworkManager)
- `customConfig.desktop` - Desktop environments (minimal support, focus on headless)
- `customConfig.services` - System services (SSH, WireGuard, vscode-server)
- `customConfig.homelab` - Homelab services (Samba, Jellyfin, media setup, *arr stack)

### Available Hosts
- `optiplex-nas` - Primary NAS server with Samba, encrypted drives, and media services
- `gaming-pc` - Development/desktop machine
- `blaney-pc` - Desktop configuration
- `justus-pc` - Desktop configuration
- `asus-laptop` - Laptop configuration
- `atl-mini-pc` - Mini PC configuration
- `optiplex` - Desktop configuration

## Homelab & NAS Features

This branch focuses primarily on homelab and NAS functionality:

### Samba File Sharing
Configure via `customConfig.homelab.samba`:
- Main public share on standard Samba ports
- Optional private encrypted share on custom port (4445)
- Automatic permission management via systemd tmpfiles

### Media Services
Available via `customConfig.homelab`:
- **Jellyfin** - Media server with optional hardware transcoding
- ***arr stack** - Radarr, Sonarr, Prowlarr, Bazarr for media management
- **Media Setup** - Shared configuration for storage and cache paths

### Network Configuration
Static IP support via `customConfig.networking.staticIP`:
- Interface specification
- IP address and gateway configuration
- Firewall management

### Encrypted Storage
The `optiplex-nas` host demonstrates LUKS encrypted drive configuration:
- Automatic decryption at boot using keyfiles
- `nofail` mount options for removable drives
- Proper permission management

## Working with Themes

**Note:** This branch has limited theme support compared to main branches. Most desktop theming features have been removed as this branch focuses on server/NAS functionality.

Basic theme configuration is set via `customConfig.homeManager.themes` (KDE and Hyprland options available for desktop hosts).

## Development Profiles

Limited development profiles are available via `customConfig.profiles.development`:
- `kernel.enable` - Linux kernel development (primarily for reference host)
- `fpga-ice40.enable` - FPGA development tools

Gaming profile also available via `customConfig.profiles.gaming.enable`.

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

### Hardware Configurations
Hardware configs are auto-generated during installation and should not be manually edited. They're stored per-host in `hosts/<hostname>/hardware-configuration.nix`.

## Installation

Use `scripts/install-new-host.sh` for fresh installations. This script:
1. Partitions disks using Disko configurations
2. Generates hardware configuration
3. Installs NixOS with the flake
4. Sets up user passwords

After first boot, run `post-install` to complete setup and establish Git access.

## After Making Changes

After making any configuration changes, always rebuild the system to apply them:

```bash
rebuild
```

This command rebuilds the current host configuration using the local flake. For testing changes without permanently switching, use:

```bash
sudo nixos-rebuild test --flake ~/nixos-config#<hostname> --impure
```

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
- **IMPORTANT**: After making file edits, run `sudo chown -R $USER:users ~/nixos-config` to restore proper file ownership
- This branch (`dev-homelab-nas`) has a reduced feature set compared to other branches - focus on homelab/NAS functionality
