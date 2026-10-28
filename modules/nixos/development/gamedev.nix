# ~/nixos-config/modules/nixos/development/gamedev.nix
{ config, pkgs, lib, ... }:

# Game development with Claude Code: the awesome-gamedev-agent-skills catalog (a router
# skill + 77 engine/discipline/genre/workflow skills) loaded as a per-session plugin, plus
# engine toolchains, behind a `gd` launcher and a ~/gamedev workspace. The counterpart of
# ./reverse-engineering.nix and built the same way. See docs/gamedev.md.

let
  cfg = config.customConfig.profiles.development.gamedev;
  userHome = config.customConfig.user.home;
  workspace = "${userHome}/gamedev";

  # Bump rev + hash together (see docs/gamedev.md). The skill list is read from the
  # repo's own marketplace.json at build time, so a bump that adds skills needs nothing
  # else here.
  skillsSrc = pkgs.fetchFromGitHub {
    owner = "gamedev-skills";
    repo = "awesome-gamedev-agent-skills";
    rev = "19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9";
    hash = "sha256-e3Wf/0h2qKqw01TH2kwJMDYqpO+G8x1gIsUl1Z9S1ok=";
  };

  # The repo is a plugin *marketplace* (marketplace.json, no plugin.json), and
  # --plugin-dir wants a plugin. Its `gamedev` entry ("router + every skill") becomes the
  # plugin manifest. The tree keeps its layout so the router's `skills/<category>/<name>`
  # paths and each skill's references/ still resolve. Loaded only by `gd`, so no other
  # session gets 78 skill descriptions in its context.
  skillsPlugin = pkgs.runCommand "gamedev-claude-plugin" { nativeBuildInputs = [ pkgs.jq ]; } ''
    mkdir -p $out
    cp -r ${skillsSrc}/router ${skillsSrc}/skills ${skillsSrc}/LICENSE ${skillsSrc}/NOTICE $out/
    mkdir -p $out/.claude-plugin
    jq '.plugins[] | select(.name == "gamedev")
        | { name, description, skills, version: "${builtins.substring 0 7 skillsSrc.rev}" }' \
      ${skillsSrc}/.claude-plugin/marketplace.json > $out/.claude-plugin/plugin.json
    # Fail the build rather than ship a plugin with no skills if upstream renames the entry.
    [ "$(jq '.skills | length' $out/.claude-plugin/plugin.json)" -gt 0 ]
  '';

  # Engines the router covers that also run here. Unity, Unreal and Roblox have no
  # NixOS path; Bevy, Ebitengine and Defold are left out until wanted (each needs its
  # own native toolchain). The rules tell sessions so, rather than letting them guess.
  python = pkgs.python3.withPackages (ps: with ps; [
    pygame-ce  # pygame-core skill (2.5.8 = its baseline)
    pillow     # create-game-assets' scripts
    numpy
  ]);

  # Puts a game on a user's real screen from a session that runs as someone else —
  # Blaney's `vibe` sessions are root, and he is the one who has to play it. A root shell
  # has no usable display env of its own, so this borrows it from any process of the
  # user's that has one, then runs the game as that user, detached.
  #   play-on-desktop <user> <command...>
  playOnDesktop = pkgs.writeShellApplication {
    name = "play-on-desktop";
    runtimeInputs = with pkgs; [ coreutils procps gnugrep util-linux ];
    text = ''
      if [ "$#" -lt 2 ]; then
        echo "usage: play-on-desktop <user> <command...>" >&2; exit 2
      fi
      user="$1"; shift
      uid=$(id -u "$user")
      vars=()
      for pid in $(pgrep -u "$uid"); do
        env=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null) || continue
        grep -q '^WAYLAND_DISPLAY=' <<<"$env" || grep -q '^DISPLAY=' <<<"$env" || continue
        mapfile -t vars < <(grep -E '^(WAYLAND_DISPLAY|DISPLAY|XAUTHORITY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|HYPRLAND_INSTANCE_SIGNATURE)=' <<<"$env")
        break
      done
      if [ "''${#vars[@]}" -eq 0 ]; then
        echo "play-on-desktop: $user has no desktop session running" >&2; exit 1
      fi
      home=$(getent passwd "$user" | cut -d: -f6)
      log="/tmp/play-on-desktop-$user.log"
      # Redirect inside the user's shell: root cannot write a file the user owns in
      # sticky /tmp (protected_regular).
      # shellcheck disable=SC2016 # expanded by the inner sh, on purpose
      runuser -u "$user" -- env HOME="$home" PATH="$PATH" "''${vars[@]}" \
        sh -c 'exec setsid -f "$@" >"$0" 2>&1 </dev/null' "$log" "$@"
      echo "Started on $user's screen (output: $log)"
    '';
  };

  gameTools = with pkgs; [
    playOnDesktop
    unstable.godot_4 # 4.7.x, the skills' baseline; stable 26.05 ships 4.6
    love             # LÖVE 11.5
    python
    nodejs_24        # Phaser / PixiJS / three.js, via npm + vite per project
    imagemagick
    libresprite      # pixel-art editor
    sox
    ffmpeg
    xvfb-run         # run a game with no display, for screenshots
    xdotool          # send it key presses there
    gnumake
    git
  ];

  # --- Shared projects -----------------------------------------------------------------
  # Games on GitHub that more than one of us works on (prin-rpg). `gd` and Blaney's `vibe`
  # both list them, cloning on first open. The rules for working in one live in its own
  # CLAUDE.md, committed to its repo, so every clone reads the same text.
  sharedProjects = lib.mapAttrsToList (name: p: p // { inherit name; }) cfg.sharedProjects;

  # git hooks that refuse a commit on, or a push to, `main`. Only Blaney's clones get them
  # (vibe points core.hooksPath here on every open): his changes go through a PR that lando
  # merges. A private repo on a free GitHub plan has no server-side branch rules, so this
  # is the enforcement, and his rules forbid `--no-verify`.
  mainGuardHooks = pkgs.runCommand "gd-main-guard-hooks" { } ''
    mkdir -p $out
    cat > $out/pre-commit <<'EOF'
    #!/bin/sh
    if [ "$(git symbolic-ref --short -q HEAD)" = main ]; then
      echo "No commits on main here. Make a blaney/ branch, commit there, push it and open a PR." >&2
      exit 1
    fi
    EOF
    cat > $out/pre-push <<'EOF'
    #!/bin/sh
    while read -r _lref _lsha rref _rsha; do
      if [ "$rref" = refs/heads/main ]; then
        echo "Never push to main here. Push your blaney/ branch and open a PR (gh pr create)." >&2
        exit 1
      fi
    done
    EOF
    chmod +x $out/pre-commit $out/pre-push
  '';

  # --- Project scaffold ---------------------------------------------------------------
  projectGitignore = pkgs.writeText "gd-gitignore" ''
    # Godot
    .godot/
    *.import.tmp
    # Builds
    export/
    build/
    dist/
    # Node
    node_modules/
    # Python
    __pycache__/
    *.py[cod]
    .venv/
    # Screenshots taken while testing
    screenshots/
    .direnv/
  '';

  projectClaudeMd = pkgs.writeText "gd-project-CLAUDE.md" ''
    *Created by `gd new`. The rules for every game project are in `../CLAUDE.md`.*

    ## The game

    *(What it is, how it plays, what it looks like.)*

    ## How it is built

    *(Engine and version, how the files are laid out, how to run it and test it.)*
  '';

  # Every entry point into a gamedev session goes through this: `gd` below, and the game
  # mode of `vibe` (modules/nixos/programs/vibe-projects.nix), which runs it under `sudo`
  # — so the PATH has to be set after sudo, by this script, not before.
  launcher = pkgs.writeShellScript "gd-claude" ''
    export PATH=${lib.makeBinPath gameTools}:"$PATH"
    export DEV_ENV_NAME="gamedev"
    exec claude --plugin-dir ${skillsPlugin} "$@"
  '';

  # Lays out a project directory. Shared with `vibe` for the same reason as `launcher`;
  # each caller writes its own CLAUDE.md and runs its own `git init`. No engine files:
  # the session picks the engine.
  scaffold = pkgs.writeShellScript "gd-scaffold" ''
    set -eu
    dir="$1"
    mkdir -p "$dir"/assets "$dir"/docs
    install -m 644 ${projectGitignore} "$dir/.gitignore"
  '';

  gd = pkgs.writeShellApplication {
    name = "gd";
    runtimeInputs = with pkgs; [ coreutils git findutils gawk gnused gh ];
    text = ''
      ws=${lib.escapeShellArg workspace}
      mkdir -p "$ws"

      usage() {
        cat <<'EOF'
      gd                 pick a game (or start one) and open Claude in it
      gd new <name>      create ~/gamedev/<name>
      gd <name> [args]   open Claude in a game; extra args go to claude (-c, -r ...)
      gd ls              list games
      EOF
      }

      create() {
        local name="$1" dir="$ws/$1"
        if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
          echo "gd: project names are letters, digits, '.', '_' and '-' only" >&2; exit 1
        fi
        if [ -e "$dir" ]; then echo "gd: $dir already exists" >&2; exit 1; fi
        ${scaffold} "$dir"
        install -m 644 ${projectClaudeMd} "$dir/CLAUDE.md"
        git -C "$dir" init -q -b main
        echo "Created $dir"
      }

      open_project() {
        ensure_cloned "$1"
        local dir="$ws/$1"; shift
        if [ ! -d "$dir" ]; then echo "gd: no project '$1' in $ws (gd new <name>)" >&2; exit 1; fi
        cd "$dir"
        exec ${launcher} "$@"
      }

      # name<TAB>owner/repo for each shared project (see `sharedProjects` above).
      shared() {
        cat <<'EOF'
      ${lib.concatMapStrings (p: "${p.name}\t${p.repo}\n") sharedProjects}EOF
      }
      shared_repo() { shared | awk -F'\t' -v n="$1" '$1 == n { print $2 }'; }

      # Clone a shared project on first open. HTTPS through gh's login, so it needs no
      # SSH key; the helper is kept in the clone's config for later pushes.
      ensure_cloned() {
        local repo dir="$ws/$1"
        [ -d "$dir" ] && return 0
        repo=$(shared_repo "$1")
        [ -n "$repo" ] || return 0
        echo "Cloning $repo into $dir"
        git -c credential.helper= -c credential.helper='!gh auth git-credential' \
          clone -q "https://github.com/$repo.git" "$dir"
        git -C "$dir" config credential.helper ""
        git -C "$dir" config --add credential.helper '!gh auth git-credential'
      }

      projects() {
        { find "$ws" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n'
          shared | cut -f1 | sed '/^$/d'; } | sort -u
      }

      case "''${1:-}" in
        -h|--help|help) usage ;;
        ls) projects ;;
        new)
          [ -n "''${2:-}" ] || { usage; exit 1; }
          create "$2"
          ;;
        "")
          mapfile -t list < <(projects)
          echo "Game projects in $ws:"
          for i in "''${!list[@]}"; do
            label="''${list[$i]}"
            if [ -n "$(shared_repo "$label")" ]; then label="$label  (shared: $(shared_repo "$label"))"; fi
            printf '  %d) %s\n' "$((i + 1))" "$label"
          done
          echo "  n) new project"
          read -rp "> " pick
          if [ "$pick" = n ]; then
            read -rp "Project name: " name
            create "$name"
            open_project "$name"
          elif [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "''${#list[@]}" ]; then
            open_project "''${list[$((pick - 1))]}"
          else
            echo "gd: nothing picked" >&2; exit 1
          fi
          ;;
        *) open_project "$@" ;;
      esac
    '';
  };
in
{
  options.customConfig.profiles.development.gamedev = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install game-engine toolchains (Godot, LÖVE, pygame-ce, Node) and the
        awesome-gamedev-agent-skills catalog for Claude Code, the `gd` launcher that
        opens Claude with those skills, and the `gamedev` dev shell used by ~/gamedev.
      '';
    };

    workspace.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the `gd` command and create the ~/gamedev workspace. Turn this off where
        game projects are only reached through `vibe` (blaney-pc): `gd` runs Claude
        without sudo, and that user's Claude login exists only for root.
      '';
    };

    sharedProjects = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          repo = mkOption {
            type = types.str;
            example = "landonreekstin/prin-rpg";
            description = "GitHub `owner/repo` to clone over HTTPS with gh's login.";
          };
          title = mkOption {
            type = types.str;
            description = "Plain-English name shown in Blaney's `vibe` menu.";
          };
        };
      });
      default = { };
      description = ''
        Games on GitHub that several people work on, keyed by folder name. `gd` lists them
        and clones one into ~/gamedev on first open. `vibe` lists them as well, and clones
        into its projects folder with git hooks that keep the user off `main`. The rules
        for working in one are in its own CLAUDE.md.
      '';
    };

    mainGuardHooks = mkOption {
      type = types.package;
      internal = true;
      readOnly = true;
      default = mainGuardHooks;
      description = "core.hooksPath directory refusing commits on and pushes to main.";
    };

    devShell = mkOption {
      type = types.package;
      internal = true;
      description = "Dev shell for the ~/gamedev workspace.";
    };

    # Read-only hooks for `vibe`, so its game projects open in exactly the environment
    # `gd` sets up.
    launcher = mkOption {
      type = types.package;
      internal = true;
      readOnly = true;
      default = launcher;
      description = "`claude` wrapper with the gamedev skills plugin and engines on PATH.";
    };

    scaffold = mkOption {
      type = types.package;
      internal = true;
      readOnly = true;
      default = scaffold;
      description = "Script that lays out a game project directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.unstable.godot_4 # the editor, for opening a project by hand
      pkgs.libresprite
    ] ++ lib.optional cfg.workspace.enable gd;

    customConfig.profiles.development.gamedev.devShell = pkgs.mkShell {
      name = "gamedev";
      packages = gameTools;
      shellHook = ''
        export DEV_ENV_NAME="gamedev"
      '';
    };
  };
}
