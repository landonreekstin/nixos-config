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
gd pong              # Claude with the gamedev skills, engines on PATH
gd pong -c           # extra args go to claude (continue / resume)
gd                   # numbered picker
nix develop ~/nixos-config#gamedev   # same tools without Claude (direnv does this in ~/gamedev)
```

Sessions run as **lando**. No engine is chosen at `gd new`: the session picks one (Godot
unless there is a reason not to — the router's own default) and creates its files.

## How it is put together

| Piece | What it is |
|---|---|
| skills plugin | `fetchFromGitHub` pin of the skills repo, copied into a store-path Claude Code plugin. The repo is a plugin *marketplace* with no `plugin.json`, so the build generates one with `jq` from the marketplace's `gamedev` entry (router + every skill). The tree keeps its layout so the router's `skills/<category>/<name>` paths and each skill's `references/` resolve. Skills show up as `gamedev:<name>`. |
| `gd` | cd into the project, then the launcher. Only these sessions see the 78 skill descriptions. |
| `launcher` / `scaffold` | read-only internal options: `gd-claude` (engines on PATH, `exec claude --plugin-dir <plugin>`) and `gd-scaffold <dir>`. `gd` uses both, and so does the game mode of Blaney's `vibe` — see [hosts/blaney-vibe-projects.md](hosts/blaney-vibe-projects.md#game-projects). |
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
