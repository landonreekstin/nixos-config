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
`/home/insideabush/projects/hud` on blaney-pc; the program is its `glade/` folder)
Package: `pkgs/glade/default.nix`, used by `modules/home-manager/hyprland/desktops/glade/desktop.nix`

The Glade, his pixel-art forest desktop. Only his GitHub account can push to the repo, so a
bump happens on blaney-pc: commit in `~/projects/hud` (his project, his `main` — see
[blaney-vibe-projects.md](hosts/blaney-vibe-projects.md)) and push it as him
(`sudo -u insideabush -H git -c credential.helper='!gh auth git-credential' push origin main`
— `gh` is signed in as `cblaney00`). Then set `rev` to the pushed sha, `version` to its
commit date, and get `hash` with the `lib.fakeHash` build. Pin only commits whose
`glade/` is meant to ship: his `main` can run ahead of the pin with work still being tried
out on a `blaney/` branch. Verify by logging into Hyprland on blaney-pc (the Glade on both
monitors, a board click opens its app).

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

## browser-puck

Source: `github:landonreekstin/browser-puck` (checkout at `/home/lando/browser-puck` on gaming-pc)
Package: `pkgs/browser-puck/default.nix` (`buildNpmPackage`), run by
`modules/nixos/homelab/browser-puck.nix` on mini-server

The team air-hockey browser game: one Node process serves the web client and its WebSocket
on port 8787. Players reach it at `http://192.168.1.76:8787` (see
[networking.md](networking.md#browser-puck-port-8787)). Bump like hyprland-keys below (repo
name `browser-puck`) and bump `version` (the date). **Also bump `npmDepsHash` whenever the
repo's `package-lock.json` changed:** set it to `lib.fakeHash`, build, and copy the real hash
from the mismatch error. Before pinning, run the repo's own checks against a production build
(its `docs/DEPLOY.md`). After the rebuild on mini-server, verify from gaming-pc with
`CLIENT_URL=http://192.168.1.76:8787 PUCK_URL=ws://192.168.1.76:8787/ws npm run verify:room`
in the browser-puck checkout.

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

