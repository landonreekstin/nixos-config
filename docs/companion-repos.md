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

## glade

Source: `github:cblaney00/glade` (insideabush's own vibe project, checkout at
`/home/insideabush/projects/glade` on blaney-pc; the program is its `glade/` folder)
Package: `pkgs/glade/default.nix`, used by `modules/home-manager/hyprland/desktops/glade/desktop.nix`

The Glade, his pixel-art forest desktop. Only his GitHub account can push to the repo, so a
bump happens on blaney-pc: commit in `~/projects/glade` (his project, his `main` — see
[blaney-vibe-projects.md](hosts/blaney-vibe-projects.md)) and push it as him
(`sudo -u insideabush -H git -c credential.helper='!gh auth git-credential' push origin main`
— `gh` is signed in as `cblaney00`). Then set `rev` to the pushed sha, `version` to its
commit date, and get `hash` with the `lib.fakeHash` build. Pin only commits whose
`glade/` is meant to ship: his `main` can run ahead of the pin with work still being tried
out on a `blaney/` branch. Verify by logging into Hyprland on blaney-pc (the Glade on both
monitors, a board click opens its app).

The glade itself (not glade-status, games or dock) also follows `main` without a bump:
`modules/home-manager/hyprland/desktops/glade/follow.nix` builds each new `main` commit into
`~/.local/state/glade/latest` every two minutes, and Thunderstorm loads it. The pin is the
fallback, so still bump it for anything outside the glade itself.

## r62d

- **Repo:** `github.com/cblaney00/r62d` — insideabush's tactical 5v5 browser game (his vibe
  project `~/projects/r62d`; he and his sessions keep working on it there).
- **Pinned in:** `pkgs/r62d/default.nix` (`rev`, `hash`)
- **Module:** `modules/nixos/programs/r62d.nix` (`customConfig.programs.r62d.enable`, plus
  `openFirewall` for TCP 6262 so friends can join a game hosted on that machine).
- **Bump:** same as glade. The repo is plain JavaScript with no npm dependencies, so the
  package is just the source plus a `r62d-server` wrapper; data lives in
  `~/.local/share/r62d/data`. The menu entry runs `r62d` (server if needed + Firefox kiosk).

## f-117

Source: `github:cblaney00/f-117`, a blank-slate copy of insideabush's vibe project
`/home/insideabush/projects/breifing-room` on blaney-pc
Package: `pkgs/f-117/default.nix` (flake output `.#f-117`)

F-117 (Briefing Room), his news-briefing app. Unlike the Glade, the project itself has **no
remote**: its history and dev notes are personal, so a clean copy is published instead. To
bump, on blaney-pc: commit in the project, run its `./publish.sh` (it re-runs itself as
insideabush, whose `gh` is signed in as `cblaney00`, and pushes everything except
CLAUDE.md, run.sh, publish.sh, .envrc and .vibe-project). It prints the pushed sha. Set `rev` to
it, `version` to its date, and get `hash` with the `lib.fakeHash` build. His own feeds live in
`~/.local/share/briefing-room/sources.json`, never in the repo. Verify with
`nix run .#f-117`.

## xbox360-dashboard

Source: `github:landonreekstin/xbox360-dashboard` (checkout at `/home/lando/xbox360-dashboard`
on gaming-pc)
Package: `pkgs/xbox360-dashboard/default.nix`, used by `modules/home-manager/hyprland/desktops/xbox360/session.nix`

The Quickshell shell, blade shader source and Python helpers of the Xbox 360 Dashboard
session; split out of this repo with its history. Bump like hyprland-keys below, with repo
path `/home/lando/xbox360-dashboard` and repo name `xbox360-dashboard`, and bump `version`
(the date). If the change reads a new `Cfg.<name>`, the matching `var` in `session.nix`'s
`configJs` lands in the same PR. To test unpushed work, set
`customConfig.homeManager.themes.xbox360.devSource = "/home/lando/xbox360-dashboard";` in the
host and `rebuild` (never commit it). Verify by logging into "Xbox 360 Dashboard".

## steel-horizon-recomp

Source: `github:landonreekstin/steel-horizon-recomp`
Package: `pkgs/steel-horizon/default.nix`, used by `modules/nixos/programs/steel-horizon.nix`

Steel Horizon RTS, the naval battle game on the PSP game's assets. Bump like hyprland-keys
below, with repo path `/home/lando/reverse-engineering/steel-horizon-recomp` and repo name
`steel-horizon-recomp`, and bump `version` (the date). The ISO is not in the package: it
sits in the NAS public drop (`/mnt/nas/public/steel-horizon/steel-horizon.iso` from
gaming-pc) and the launcher rebuilds `~/.local/share/steel-horizon/assets` from it whenever
the package path changes, so a bump also picks up new asset tools. Online games are
lockstep: players need the same pin. Verify with `steel-horizon` from the start menu
(first run: download and unpack, then the game's menu).

## jakks-batman-recomp

Source: `github:landonreekstin/jakks-batman-recomp`
Package: `pkgs/batman/default.nix`, used by `modules/nixos/programs/batman.nix`

Pinned with `fetchFromGitHub`, and bumped like hyprland-keys below: use the repo path
`/home/lando/reverse-engineering/jakks-batman-recomp` and repo name `jakks-batman-recomp`.
Online players must run the same build (the host refuses any other), so gaming-pc and
blaney-pc both need to be on the new pin. Bump `version` (the date) too.

## game-control

Source: `github:landonreekstin/game-control`
Package: `pkgs/game-control/default.nix` (just the pinned source), run by
`modules/nixos/homelab/game-control.nix` on mini-server

The FastAPI game-server dashboard (`app.py` + `templates/`). The server tiles are the
`SERVERS` table in `app.py`, so adding a game server means a commit there as well as the
container in `modules/nixos/homelab/game-servers.nix`. Bump like hyprland-keys below (repo
name `game-control`), then rebuild on mini-server and load the dashboard to verify.

## xr-srgb-fix

Source: `github:landonreekstin/xr-srgb-fix`
Package: `pkgs/xr-srgb-fix/default.nix` (the build and the layer manifest live here), used by
`modules/nixos/profiles/vr.nix`

The OpenXR layer from [vr.md](vr.md). Bump like hyprland-keys below (repo name
`xr-srgb-fix`), rebuild on gaming-pc, and verify in the headset with War Thunder (colours
match the desktop mirror).

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

