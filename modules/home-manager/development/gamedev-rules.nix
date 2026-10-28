# ~/nixos-config/modules/home-manager/development/gamedev-rules.nix
#
# Not a module: the part of the game-dev CLAUDE.md that is the same wherever a gamedev
# session runs. Imported by ./gamedev.nix (lando's ~/gamedev workspace) and
# ./vibe-projects.nix (insideabush's game projects under ~/projects), which each put their
# own header above it. The counterpart of ./reverse-engineering-rules.nix.
{
  # How a session is allowed to run the game it is building (one bullet, Markdown).
  runGameRule,
  # Where a missing tool should be requested (one sentence, Markdown).
  missingToolRule,
}:

''
  ## Skills: let the router pick

  This session has the **awesome-gamedev-agent-skills** catalog loaded as the `gamedev`
  plugin: a `router` skill and ~77 skills for engines, disciplines (game feel, cameras,
  AI, saving, UI, shaders, art direction ...), genres and shipping.

  - At the start of every game-dev task, and again whenever the task changes direction,
    invoke the **`gamedev:router`** skill and do what it says: it fingerprints the
    project, names the few skills that apply, and you read only those.
  - Don't bulk-load skills, and don't name a skill that is not in the catalog.
  - Skill files are read-only (they live in the Nix store). Nothing to install —
    never run `npx skills add` or `claude plugin install`.

  ## Engines installed here

  | Engine | Command | Version |
  |---|---|---|
  | Godot | `godot` | 4.7 — **the default for a new game** (the router's own default) |
  | LÖVE | `love` | 11.5 |
  | pygame-ce | `python3` (with `pygame`, `pillow`, `numpy`) | 2.5 |
  | Phaser / PixiJS / three.js | `node`, `npm` (add the library with npm in the project) | Node 24 |

  **Not installed:** Unity, Unreal and Roblox (no way to run them here), and Bevy,
  Ebitengine and Defold. If a game would need one of those, say so plainly instead of
  quietly switching engines. Godot's export templates are not installed either, so
  `godot --export-*` will fail; running and testing a project does not need them.

  Also on PATH: `imagemagick` (`magick`), `libresprite` (pixel art), `sox`, `ffmpeg`,
  `xvfb-run`, `xdotool`, `git`. ${missingToolRule}

  ## Project layout

  | Path | Holds |
  |---|---|
  | `assets/` | art, audio and fonts used by the game |
  | `docs/` | design notes, anything longer than CLAUDE.md should carry |
  | `CLAUDE.md` | what the game is and how it is built — keep it current |
  | engine files | whatever the chosen engine wants (`project.godot`, `main.lua`, `package.json`, ...) at the project root |

  ## Checking that it works

  A game "works" when it has been **run and looked at**, not when it parses.

  - Godot: `godot --headless --path . --quit-after 120` catches script errors without a
    window; GDScript tests run headless as the `godot-gdscript-headless-testing` skill
    describes.
  - To see it, run it in a virtual display and take a screenshot, then open the PNG
    with the Read tool:

    ```
    mkdir -p screenshots
    xvfb-run -a -s "-screen 0 1280x720x24" sh -c \
      'godot --path . --rendering-driver opengl3 & sleep 6; magick import -window root screenshots/shot.png; kill $!'
    ```

    (swap the `godot ...` for `love .`, `python3 main.py`, or a browser build). Use
    `xdotool key ...` inside the same `sh -c` to press keys before the screenshot.
  ${runGameRule}
  - Commit whenever the game is in a playable state, so there is always one to go
    back to.
''
