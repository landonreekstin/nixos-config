# Game development (`gd`)

`customConfig.profiles.development.gamedev.enable` (on gaming-pc and blaney-pc) installs
engine toolchains plus the
[awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
catalog for Claude Code: a `router` skill that fingerprints the project (`project.godot`,
`main.lua`, `package.json` …) and loads only the few skills that apply, plus 77 engine,
discipline (game feel, cameras, AI, saving, UI, shaders, art direction), genre and
shipping skills. It is built the same way as [reverse-engineering.md](reverse-engineering.md).

- NixOS side: `modules/nixos/development/gamedev.nix`
- Workspace (`.envrc`, parent `CLAUDE.md`): `modules/home-manager/development/gamedev.nix`
- Rules shared with Blaney's `vibe` game projects: `modules/home-manager/development/gamedev-rules.nix`

## Using it

```bash
gd new pong          # creates ~/gamedev/pong/{assets,docs} + .gitignore, git init
cd ~/gamedev/pong
claude               # direnv's dev shell: gamedev skills, engines on PATH
claude -c            # continue / resume as usual
gd ls                # list games (shared ones too)
nix develop ~/nixos-config#gamedev   # same tools without Claude (direnv does this in ~/gamedev)
```

Sessions run as **lando**. No engine is chosen at `gd new`: the session picks one (Godot
unless there is a reason not to — the router's own default) and creates its files.

## How it is put together

| Piece | What it is |
|---|---|
| skills plugin | `fetchFromGitHub` pin of the skills repo, copied into a store-path Claude Code plugin. The repo is a plugin *marketplace* with no `plugin.json`, so the build generates one with `jq` from the marketplace's `gamedev` entry (router + every skill). The tree keeps its layout so the router's `skills/<category>/<name>` paths and each skill's `references/` resolve. Skills show up as `gamedev:<name>`. |
| dev shell | `nix develop ~/nixos-config#gamedev`, or direnv in `~/gamedev` (so every project under it). Engines plus a `claude` wrapper (`devClaude`) that runs the next `claude` on PATH with `--plugin-dir <plugin>`. Only sessions started inside it see the 78 skill descriptions. |
| `gd` | `gd new <name>` (scaffold, or clone for a shared project) and `gd ls`. Opening a game is just `cd` + `claude`. |
| `launcher` / `scaffold` | read-only internal options: `gd-claude` (engines on PATH, `exec claude --plugin-dir <plugin>`) and `gd-scaffold <dir>`. Used by the game mode of Blaney's `vibe`, which runs Claude under `sudo` with no direnv — see [hosts/blaney-vibe-projects.md](hosts/blaney-vibe-projects.md#game-projects). `gd new` uses `scaffold`. |
| `play-on-desktop <user> <cmd…>` | on the launcher's PATH. Runs a game on a user's real screen from a session that is someone else (Blaney's root `vibe` sessions): it copies `WAYLAND_DISPLAY`/`DISPLAY`/`XDG_RUNTIME_DIR`/… from any of that user's processes that has them and `runuser`s the command detached. Log in `/tmp/play-on-desktop-<user>.log`. |
| dev shell | `devShells.gamedev`, built from gaming-pc's config like every other shell. |

`workspace.enable` (default `true`) gates `gd` and `~/gamedev`. blaney-pc sets it `false`:
there game projects are reached only through `vibe`, since his Claude login is root's.

### Engines

| Engine | Package | Why that one |
|---|---|---|
| Godot 4.7 | `unstable.godot_4` | the skills target 4.7; 26.05 ships 4.6. Drop `unstable.` once stable reaches 4.7 |
| LÖVE 11.5 | `love` | |
| pygame-ce 2.5 | `python3.withPackages` (+ Pillow, numpy — Pillow also runs `create-game-assets`' scripts) | |
| Phaser / PixiJS / three.js | `nodejs_24` | libraries come from npm per project |

Plus `imagemagick`, `libresprite`, `sox`, `ffmpeg`, `xvfb-run`, `xdotool`.

Checking a game without a display: `xvfb-run` + `--rendering-driver opengl3` renders
Godot on llvmpipe, and `magick import -window root` grabs the frame — the recipe is in
the rules file and was checked when this was added.

## Shared projects (prin-rpg, sub-of-seas)

`gamedev.sharedProjects.<name> = { repo; title; forge; blaneyCommitsToMain; }` lists a game
repo that more than one person works on. `gd ls` lists it (marked if not yet cloned), and
`gd new <name>` for it clones the repo into `~/gamedev/<name>` over HTTPS. Blaney's `vibe`
gets a "Work on <title> with Lando" entry; see
[hosts/blaney-vibe-projects.md](hosts/blaney-vibe-projects.md#games-shared-with-lando-prin-rpg).

| Game | Where | Credential helper | Blaney |
|---|---|---|---|
| prin-rpg | our Forgejo, `http://192.168.1.76:3000/lando/prin-rpg` ([forgejo.md](forgejo.md)) | `homelab` (the host's Forgejo token) | commits to `main` |
| sub-of-seas | GitHub `landonreekstin/sub-of-seas` | `gh auth git-credential` | `blaney/` branches + PRs that lando merges |

The rules are written in each project's own `CLAUDE.md` and summarised in
`~/gamedev/CLAUDE.md`. Verify before you commit, either way. GitHub's free plan can't
enforce the PR flow on a private repo, so for a PR-flow game Blaney's clone gets
`mainGuardHooks` (pre-commit and pre-push hooks that refuse `main`). `vibe` sets or
removes them on every open, following `blaneyCommitsToMain`.

## Playing a game with others before it has a build (sub-of-seas)

Godot export templates aren't installed, but a Godot **pack** (`.pck`, just the project's
files) exports without them and runs on any machine with the same Godot:
`godot --main-pack game.pck`. Sub of Seas ships that way. `pkgs/sub-of-seas` pins the
(public) game repo and exports the pack during the Nix build, and
`customConfig.programs.sub-of-seas` (`modules/nixos/programs/sub-of-seas.nix`, on gaming-pc
and blaney-pc) installs a `sub-of-seas` launcher that runs it on `unstable.godot_4`. A new
build reaches players by bumping the pin (docs/companion-repos.md) and rebuilding; host and
players must be on the same pin. Its online port is 7845, so it rides the existing Batman
forward from optiplex-fw to gaming-pc over the VPN.

## Known gaps

- **Unity, Unreal, Roblox**: no Linux/Nix path. The rules tell sessions to say so rather
  than switch engines silently.
- **Bevy, Ebitengine, Defold**: not installed (each needs its own native toolchain:
  Rust + udev/alsa/vulkan, Go + X11/GL, `bob.jar` + JDK). Add to `gameTools` when wanted.
- **Godot export templates** (`godot_4-export-templates-bin`, ~1 GB) are not installed,
  so `godot --export-*` fails. Running and headless testing do not need them.

## Bumping the skills

1. Set `rev` in `skillsSrc` in `modules/nixos/development/gamedev.nix`.
2. `nix run nixpkgs#nix-prefetch-github -- gamedev-skills awesome-gamedev-agent-skills --rev <rev>`
   and copy the `hash`.
3. Build the launcher and count the skills:
   `jq '.skills | length' <plugin>/.claude-plugin/plugin.json` (the build fails if the
   `gamedev` entry disappears upstream).
4. Read upstream's `docs/VERSION-SUPPORT.md` — if a baseline moved (Godot 4.8, LÖVE 12),
   move the matching package and the version table in `gamedev-rules.nix`.
