<!-- ~/nixos-config/docs/installation.md -->
> **Read this when**: deploying a brand-new host, building an installer USB, or
> re-installing an existing machine.

# Installation

## Preferred: Remote deploy via nixos-anywhere (LAN or VPN)

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

## Fallback: On-target install (no LAN access to gaming-pc)

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

## New host checklist

Before deploying, the host config must exist in git:
- `hosts/<hostname>/default.nix` — with `sopsPassword = true` in the user block
- `hosts/<hostname>/disko-config.nix` — disk layout
- `hosts/<hostname>/hardware-configuration.nix` — placeholder (`{}`) or generated
- `.sops.yaml` — anchor `&<hostname>` with `age1PLACEHOLDER_<hostname>` and a
  creation rule for `secrets/<hostname>.yaml`

After first deploy, `scripts/deploy-host.sh` fills in the real age key and
generates the hardware config automatically.

After first boot, run `post-install` to complete setup and establish Git access.

