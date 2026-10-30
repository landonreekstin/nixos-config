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

## insideabush's apps: the pin is a release

glade and r62d below (and any future `owner = "cblaney00"` package) work differently from
lando's repos. **blaney-pc never runs the pin.** `customConfig.programs.vibeProjects.localApps`
in `hosts/blaney-pc/apps.nix` maps each app to its folder in `~/projects`, and
`pkgs/vibe-local-src.nix` hands that folder to the package as `localSrc`, so every
`rebuild` there builds whatever is in the folder (committed or not; `.git`,
`node_modules`, `__pycache__`, `.direnv` and `result` left out). His sessions get a change
onto his computer with a plain `rebuild`, no config edit at all.

The pin is what everyone else gets, lando being the only other user: a **release**.

- It moves only when insideabush asks for one ("release my glade app to Lando"), never
  as a side effect of working on the app. The commit must be on GitHub's `main`.
- **One app per PR, and nothing else in it**: `blaney/release-<app>`, cut fresh from
  `origin/main`, touching only `pkgs/<app>/` (and this file). CI's `release-pins` job
  fails any PR that moves one of these pins next to other changes, or moves two.
- One open release PR per app. A newer release re-cuts the same branch from `origin/main`
  and force-pushes it; a release branch that falls behind or conflicts is re-cut, never
  rebased or resolved. Since it is three lines (`rev`, `hash`, `version`), that is
  always trivial.
- A config PR that needs something new in the app says "needs the release PR merged
  first" instead of bumping the pin itself.

Why: #242, #248 and #249 all hit merge conflicts on these pins. Each blaney-pc session
bumped the pin to see its change (and #248/#249 carried cherry-picked bumps from #247),
while other bumps kept landing on `main` (ten r62d bumps from the notes runs in a day).
Every PR that touched the pin conflicted with every other one. With his machine building
from the folder, nothing but a release has a reason to touch the pin.

The rules are in the three places his sessions read: `~/projects/CLAUDE.md`
(`modules/home-manager/development/vibe-projects.nix`), the config chat's `ccnRules` and
the `work-notes` prompt (both `modules/nixos/common/blaney-commands.nix`).

To check what blaney-pc would build without being on it, point the config at a scratch
copy of `~/projects`:

```bash
nix build --impure --no-link --print-out-paths --expr 'let f = builtins.getFlake (toString ./.);
  c = (f.nixosConfigurations.blaney-pc.extendModules { modules = [ {
    customConfig.programs.vibeProjects.dir = f.inputs.nixpkgs.lib.mkForce "/path/to/projects"; } ]; }).config;
in builtins.filter (p: builtins.elem (p.pname or "") [ "glade" "r62d" "vibenote" ])
  (c.environment.systemPackages ++ c.home-manager.users.insideabush.home.packages)'
```

The packages come out as `<app>-0-local`. If a listed folder is missing on blaney-pc, eval
prints a `trace: warning: vibeProjects.localApps.<app>` line and falls back to the pin.

## glade

Source: `github:cblaney00/glade` (insideabush's own vibe project, checkout at
`/home/insideabush/projects/glade` on blaney-pc; the program is its `glade/` folder)
Package: `pkgs/glade/default.nix`, used by `modules/home-manager/hyprland/desktops/glade/desktop.nix`

The Glade, his pixel-art forest desktop. blaney-pc builds it from his project folder, and
the pin is a release ([above](#insideabushs-apps-the-pin-is-a-release)). Only his GitHub
account can push to the repo, so a release happens on blaney-pc: his project's `main` is
pushed as him
(`sudo -u insideabush -H git -c credential.helper='!gh auth git-credential' push origin main`
— `gh` is signed in as `cblaney00`). Then set `rev` to the pushed sha, `version` to its
commit date, and get `hash` with the `lib.fakeHash` build. Verify a change to the Glade by
rebuilding and logging into Hyprland on blaney-pc (the Glade on both monitors, a board
click opens its app); verify a release by building the pinned package.

## r62d

- **Repo:** `github.com/cblaney00/r62d` — insideabush's tactical 5v5 browser game (his vibe
  project `~/projects/r62d`; he and his sessions keep working on it there).
- **Pinned in:** `pkgs/r62d/default.nix` (`rev`, `hash`)
- **Module:** `modules/nixos/programs/r62d.nix` (`customConfig.programs.r62d.enable`, plus
  `openFirewall` for TCP 6262 so friends can join a game hosted on that machine).
- **Release:** same as glade; blaney-pc builds it from `~/projects/r62d`. The repo is plain JavaScript with no npm dependencies, so the
  package is just the source plus a `r62d-server` wrapper; data lives in
  `~/.local/share/r62d/data`. The menu entry runs `r62d` (server if needed + Firefox kiosk).

## vibenote

- **Repo:** `github.com/cblaney00/vibenote` — insideabush's per-project notes app (his vibe
  project `~/projects/vibenote`; he and his sessions keep working on it there).
- **Pinned in:** `pkgs/vibenote/default.nix` (`rev`, `hash`)
- **Module:** `modules/nixos/programs/vibenote.nix` (`customConfig.programs.vibenote.enable`).
- **Release:** same as glade; blaney-pc builds it from `~/projects/vibenote`. Plain Python,
  standard library only (tkinter), so the package is the source plus a `vibenote` wrapper;
  notes live in `~/.local/share/vibenote/notes.json`. The menu entry runs `vibenote`.

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

## sub-of-seas

Source: `github:landonreekstin/sub-of-seas`
Package: `pkgs/sub-of-seas/default.nix`, used by `modules/nixos/programs/sub-of-seas.nix`

Lando's co-op Godot submarine game. Bump like hyprland-keys below, with repo path
`/home/lando/gamedev/sub-of-seas` and repo name `sub-of-seas`, and bump `version` (the
date). The build exports a `.pck` with the pin's short rev as its build name; players and
host must match, so gaming-pc and blaney-pc both need the new pin. Verify with
`sub-of-seas` from the start menu (the main menu says "Build <short rev>").

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

