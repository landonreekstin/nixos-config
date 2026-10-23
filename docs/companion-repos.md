<!-- ~/nixos-config/docs/companion-repos.md -->
> **Read this when**: a package in this repo is pinned to another repo of ours and the
> pin needs bumping.

# Companion Repositories

**Standing rule** (also in `CLAUDE.md`): an app that is not Nix — Python, QML, C, Rust, a
game, a shell UI — lives in its own repo and is only *packaged* here, with a
`fetchFromGitHub` pin in `pkgs/<name>/default.nix`. Never vendor its source into
`pkgs/<name>/src`. Inline `writeShellScript` glue that only wires config together is not an
"app" and stays put. Every such repo gets a section below.

Getting the `hash` for a new rev: either the `nix-prefetch-url` recipe under hyprland-keys,
or set `hash = lib.fakeHash;`, build, and copy the real hash out of the mismatch error.

Still vendored, to be moved out under this rule:
- `pkgs/glade/src` → `github:cblaney00/glade` (PR #203; the repo exists, the pin is the
  last step — the vendored copy matches rev `e7d5c2f`).

## xbox360-dashboard

Source: `github:landonreekstin/xbox360-dashboard` (checkout at `/home/lando/xbox360-dashboard`
on gaming-pc)
Package: `pkgs/xbox360-dashboard/default.nix`, used by `modules/home-manager/themes/xbox360/session.nix`

The Quickshell shell, blade shader source and Python helpers of the Xbox 360 Dashboard
session; split out of this repo with its history. Bump like hyprland-keys below, with repo
path `/home/lando/xbox360-dashboard` and repo name `xbox360-dashboard`, and bump `version`
(the date). If the change reads a new `Cfg.<name>`, the matching `var` in `session.nix`'s
`configJs` lands in the same PR. To test unpushed work, set
`customConfig.homeManager.themes.xbox360.devSource = "/home/lando/xbox360-dashboard";` in the
host and `rebuild` (never commit it). Verify by logging into "Xbox 360 Dashboard".

## jakks-batman-recomp

Source: `github:landonreekstin/jakks-batman-recomp`
Package: `pkgs/batman/default.nix`, used by `modules/nixos/programs/batman.nix`

Pinned with `fetchFromGitHub`, and bumped like hyprland-keys below: use the repo path
`/home/lando/reverse-engineering/jakks-batman-recomp` and repo name `jakks-batman-recomp`.
Online players must run the same build (the host refuses any other), so gaming-pc and
blaney-pc both need to be on the new pin. Bump `version` (the date) too.

## hyprland-keys

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

