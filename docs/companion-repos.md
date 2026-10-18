<!-- ~/nixos-config/docs/companion-repos.md -->
> **Read this when**: a package in this repo is pinned to another repo of ours and the
> pin needs bumping.

# Companion Repositories

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

