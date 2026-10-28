# ~/nixos-config/modules/nixos/programs/vibe-projects.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig;
  vibeCfg = cfg.programs.vibeProjects;

  userName = cfg.user.name;
  userEmail = cfg.user.email;
  configDir = "${cfg.user.home}/nixos-config";
  projectsDir = vibeCfg.dir;

  # Reverse-engineering projects ("take apart a program or game") are offered only where
  # the REA profile is on. Every reference to its store paths sits behind this flag, so a
  # host without it does not pull Ghidra and friends into its closure through `vibe`.
  reCfg = cfg.profiles.development.reverse-engineering;
  reEnabled = reCfg.enable;

  # Game projects ("make a game") likewise, behind the gamedev profile.
  gdCfg = cfg.profiles.development.gamedev;
  gdEnabled = gdCfg.enable;

  # The Glade Claude-panel hooks every plain project session gets; game sessions pass
  # them through the gamedev launcher too.
  panelHooks = (import ../../home-manager/hyprland/desktops/glade/claude-panel.nix { inherit pkgs; }).hooks;

  # --- Text assets -----------------------------------------------------------------
  # Every multi-line text below is a writeText store file that the script `cat`s or
  # `install`s, not a heredoc inside the script. `blaney-todo` builds its prompt with an
  # unquoted heredoc and therefore has to carry a "no backticks in here" warning, and its
  # terminator only lands at column 0 because every line of that Nix string happens to be
  # indented. Reading a store file means this text is never parsed by bash at all, so it
  # can hold backticks, quotes and ${...} freely — only Nix's own ''${ escape applies.

  # Deliberately short. The rules for a session in here are in the PARENT directory's
  # CLAUDE.md, installed by modules/home-manager/development/vibe-projects.nix: Claude Code
  # collects CLAUDE.md from the working directory upwards, so one file above the projects
  # reaches every session including `claude -c` / `claude -r`, which carry no prompt. A copy
  # frozen into each project at creation time would go stale the first time a rule changed.
  # The pointer below is the belt-and-braces: if parent discovery ever does not fire, the
  # session is still told where the rules are.
  projectClaudeMd = pkgs.writeText "vibe-project-CLAUDE.md" ''
    *Created by the `vibe` command. Keep the two sections below current as the app grows —
    a future session starts by reading them.*

    > **The rules for working here are in `../CLAUDE.md`** (one directory up, alongside the
    > other apps). They are loaded automatically; if for any reason they are not in your
    > context, read that file before doing anything else.

    ## What this app is

    *(Fill this in: one paragraph on what the app does, who it is for, and what it should
    look like. Ask him — that part is his call.)*

    ## How it is built

    *(Fill this in: the language and why, how the files are laid out, how to run it, how to
    test it. Record the dev shell on the `shell=` line of `.vibe-project` too.)*
  '';

  # The reverse-engineering counterpart. The "Reverse-engineering projects" section of
  # ../CLAUDE.md is what applies here; it is selected by `kind=re` in .vibe-project.
  reProjectClaudeMd = pkgs.writeText "vibe-re-project-CLAUDE.md" ''
    *Created by the `vibe` command as a reverse-engineering project (`kind=re` in
    `.vibe-project`). Keep the two sections below current — a future session starts by
    reading them.*

    > **The rules for working here are in `../CLAUDE.md`** (one directory up), including
    > its "Reverse-engineering projects" section. They are loaded automatically; if for any
    > reason they are not in your context, read that file before doing anything else.

    ## What we're taking apart

    *(Fill this in: the program or game in `target/`, where he got it, its SHA-256, and
    what he wants out of it — to understand how it works, to change something, or to
    rebuild it. That last part is his call.)*

    ## Status

    *(What has been worked out, what is reconstructed in `recomp/`, and how closely it
    matches the original — tests passing, functions byte-identical.)*
  '';

  # The game counterpart. The "Game projects" section of ../CLAUDE.md applies here; it is
  # selected by `kind=game` in .vibe-project.
  gameProjectClaudeMd = pkgs.writeText "vibe-game-project-CLAUDE.md" ''
    *Created by the `vibe` command as a game project (`kind=game` in `.vibe-project`). Keep
    the two sections below current — a future session starts by reading them.*

    > **The rules for working here are in `../CLAUDE.md`** (one directory up), including
    > its "Game projects" section. They are loaded automatically; if for any reason they
    > are not in your context, read that file before doing anything else.

    ## The game

    *(Fill this in: what the game is about, how you play it, and what it looks and sounds
    like. Ask him — that part is his call.)*

    ## How it is built

    *(Fill this in: the engine and why, how the files are laid out, how to run it, how to
    test it.)*
  '';

  projectGitignore = pkgs.writeText "vibe-gitignore" ''
    # Nix / direnv
    .direnv/
    result
    result-*

    # Editors
    .vscode/
    *.swp

    # Python
    __pycache__/
    *.py[cod]
    .venv/
    .ruff_cache/

    # Node
    node_modules/
    dist/
    build/
    *.log

    # OS
    .DS_Store
  '';

  # Only the dynamic framing. The binding rules come from ../CLAUDE.md, which Claude loads
  # on its own, so repeating them here would just be a second copy to keep in sync.
  sessionRules = pkgs.writeText "vibe-session-rules.md" ''
    This is a coding session in one of ${userName}'s own app projects. The working directory
    is the project itself, not the NixOS config.

    CLAUDE.md in the parent directory (${projectsDir}/CLAUDE.md) holds the rules for this
    kind of session and is binding — read it first if it is not already in your context. In
    short: ${userName} is not technical and makes no technical decisions, he does decide how
    the app looks and behaves, this project's git repo is his to commit to `main` freely,
    its code stays on this machine or in a GitHub repo on his own account and never inside
    the NixOS config, his config checkout at ${configDir} gets caught up with `main` (and
    rebuilt) at the start of every session, and anything else needing the config should be
    handed back to him to run `ccn` for rather than done from here.
  '';

  # Pre-accept the workspace-trust prompt for a directory, so a non-technical user does not
  # meet a dialog he has no way to evaluate, and report how many saved chats that directory
  # already has. Both halves need root: Claude runs as `sudo claude`, so its state lives
  # under /root (HOME=/root under sudo) and /root is 0700 — `vibe`, running as ${userName},
  # cannot look for itself. Doing both in one call means one password prompt.
  #
  # The trust key is the same one modules/nixos/programs/claude-code.nix seeds for its
  # remote-control directories; the difference is that this runs for a directory created
  # seconds ago rather than one in a statically declared list. Its own store script so
  # there is exactly one level of quoting around the jq program.
  vibePrepare = pkgs.writeShellScript "vibe-prepare" ''
    set -u
    dir="$1"

    j=/root/.claude.json
    [ -f "$j" ] || printf '{}\n' > "$j"
    t=$(mktemp)
    if ${pkgs.jq}/bin/jq --arg d "$dir" '.projects[$d].hasTrustDialogAccepted = true' "$j" > "$t"; then
      mv "$t" "$j"
      chmod 600 "$j"
    else
      rm -f "$t"
    fi

    # Claude keys its saved chats by working directory, with the slashes turned into
    # dashes. Fail soft: an unrecognised layout must report "no chats", never an error,
    # or the menu breaks for a reason the user cannot act on.
    key=$(printf '%s' "$dir" | tr '/' '-')
    n=$(ls "/root/.claude/projects/$key"/*.jsonl 2>/dev/null | ${pkgs.coreutils}/bin/wc -l)
    printf 'sessions=%s\n' "''${n:-0}"
  '';

  vibeCmd = pkgs.writeShellScriptBin "vibe" ''
    #!${pkgs.stdenv.shell}
    set -uo pipefail

    PROJECTS_DIR="${projectsDir}"
    SESSION_RULES="${sessionRules}"

    # Empty where the reverse-engineering profile is off; every RE path checks for that.
    RE_LAUNCHER="${lib.optionalString reEnabled "${reCfg.launcher}"}"
    RE_SCAFFOLD="${lib.optionalString reEnabled "${reCfg.scaffold}"}"
    RE_CLAUDE_MD="${lib.optionalString reEnabled "${reProjectClaudeMd}"}"

    # Likewise empty where the gamedev profile is off.
    GD_LAUNCHER="${lib.optionalString gdEnabled "${gdCfg.launcher}"}"
    GD_SCAFFOLD="${lib.optionalString gdEnabled "${gdCfg.scaffold}"}"
    GD_CLAUDE_MD="${lib.optionalString gdEnabled "${gameProjectClaudeMd}"}"

    mkdir -p "$PROJECTS_DIR"

    # --- helpers ---------------------------------------------------------------

    # Only [a-z0-9-] survives, so a title can never produce ".", ".." or a path
    # separator however it is typed. Capped so a rambling title cannot make an
    # unusable directory name.
    slugify() {
      printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
        | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//' \
        | cut -c1-40 | sed -e 's/-\+$//'
    }

    trim() {
      printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
    }

    # .vibe-project is what makes a folder a vibe project: title= is his own plain-English
    # name, shell= is the dev shell Claude picked for it (empty until it has), and kind=re
    # marks a reverse-engineering project (absent means an ordinary app). Read with sed
    # and never sourced — the title is arbitrary text he typed.
    marker_field() {
      sed -n "s/^$2=//p" "$1/.vibe-project" 2>/dev/null | head -n1
    }

    # Accept the trust dialog for the directory and find out whether it has past chats.
    # Fail soft: if this cannot run, carry on as though there were none.
    SESSIONS=0
    prepare_dir() {
      local info
      info=$(sudo ${vibePrepare} "$1" 2>/dev/null) || info=""
      SESSIONS=$(printf '%s' "$info" | sed -n 's/^sessions=//p' | head -n1)
      case "$SESSIONS" in
        ""|*[!0-9]*) SESSIONS=0 ;;
      esac
    }

    # run_claude <dir> <kind> [claude args...]
    # A reverse-engineering project must ALWAYS open through the launcher, resumed chats
    # included: it is what loads REA's tools (--plugin-dir) and puts Ghidra, the
    # compilers etc. on PATH. A resumed chat started with plain `claude` would have none.
    # The launcher sets that environment itself, after sudo has reset it.
    run_claude() {
      local dir="$1" kind="$2"
      shift 2
      cd "$dir" || exit 1
      if [ "$kind" = re ]; then
        if [ -z "$RE_LAUNCHER" ]; then
          echo "Taking programs apart isn't set up on this computer any more — tell Lando."
          exit 1
        fi
        exec sudo "$RE_LAUNCHER" "$@"
      fi
      # Same for a game project: the launcher is what loads the gamedev skills and puts
      # the engines on PATH.
      if [ "$kind" = game ]; then
        if [ -z "$GD_LAUNCHER" ]; then
          echo "Making games isn't set up on this computer any more — tell Lando."
          exit 1
        fi
        exec sudo "$GD_LAUNCHER" --settings ${panelHooks} "$@"
      fi
      exec sudo claude --settings ${panelHooks} "$@"
    }

    launch() {
      # launch <dir> <kind> <extra prompt text>
      local dir="$1" kind="$2" extra="$3" prompt
      prompt="$(cat "$SESSION_RULES")

    --- THIS SESSION ---
    $extra"
      run_claude "$dir" "$kind" "$prompt"
    }

    # --- new project -----------------------------------------------------------

    new_project() {
      # new_project [app|re|game]
      local kind="''${1:-app}" title slug dir noun
      case "$kind" in re) noun="project" ;; game) noun="game" ;; *) noun="app" ;; esac
      echo
      if [ "$kind" = re ]; then
        read -rp "What do you want to call this project? (the name of the program or game is fine) " title
      elif [ "$kind" = game ]; then
        read -rp "What do you want to call your game? (you can change it later) " title
      else
        read -rp "What do you want to call your app? " title
      fi
      title=$(trim "$title")
      if [ -z "$title" ]; then
        echo "You didn't type a name — nothing started."
        exit 1
      fi
      slug=$(slugify "$title")
      if [ -z "$slug" ]; then
        echo "That name has no letters or numbers in it, so I can't make a folder from it."
        exit 1
      fi
      dir="$PROJECTS_DIR/$slug"
      if [ -e "$dir" ]; then
        echo
        echo "You already have a $noun in $dir."
        echo "Pick a different name, or run vibe again and choose the one you already started."
        exit 1
      fi

      echo
      echo "Setting up $title in $dir..."
      mkdir -p "$dir"
      git -C "$dir" init -q -b main || { echo "Couldn't start a git repo there — tell Lando."; exit 1; }

      # Claude works in here as root, and root has no git identity of its own on this
      # machine (/root/.gitconfig is hand-written and only exists on lando's). git reads a
      # repo-local [user] before any global one, so writing it here is what makes commits
      # come out as him instead of failing or being attributed to someone else.
      git -C "$dir" config user.name "${userName}"
      git -C "$dir" config user.email "${userEmail}"

      # install, not cp: store files are read-only and Claude has to be able to edit these.
      if [ "$kind" = re ]; then
        # The same layout `re new` makes (target/ notes/ evidence/ recomp/ tests/, the
        # target-ignoring .gitignore and recomp/Makefile), plus the vibe .gitignore lines.
        "$RE_SCAFFOLD" "$dir" || { echo "Couldn't set the project up — tell Lando."; exit 1; }
        { printf '\n'; cat "${projectGitignore}"; } >> "$dir/.gitignore"
        printf 'title=%s\nslug=%s\nshell=reverse-engineering\nkind=re\n' "$title" "$slug" > "$dir/.vibe-project"
        { printf '# %s\n\n' "$title"; cat "$RE_CLAUDE_MD"; } > "$dir/CLAUDE.md"
      elif [ "$kind" = game ]; then
        # assets/ docs/ and the engine-aware .gitignore from `gd`'s scaffold, plus the
        # vibe .gitignore lines.
        "$GD_SCAFFOLD" "$dir" || { echo "Couldn't set the game up — tell Lando."; exit 1; }
        { printf '\n'; cat "${projectGitignore}"; } >> "$dir/.gitignore"
        printf 'title=%s\nslug=%s\nshell=gamedev\nkind=game\n' "$title" "$slug" > "$dir/.vibe-project"
        { printf '# %s\n\n' "$title"; cat "$GD_CLAUDE_MD"; } > "$dir/CLAUDE.md"
      else
        install -m 0644 "${projectGitignore}" "$dir/.gitignore"
        printf 'title=%s\nslug=%s\nshell=\n' "$title" "$slug" > "$dir/.vibe-project"
        { printf '# %s\n\n' "$title"; cat "${projectClaudeMd}"; } > "$dir/CLAUDE.md"
      fi
      chmod 0644 "$dir/CLAUDE.md"

      git -C "$dir" add -A
      git -C "$dir" commit -q -m "chore: start $title"

      prepare_dir "$dir"
      echo "Done. Starting Claude on it now."
      if [ "$kind" = re ]; then
        launch "$dir" re "The project is called: $title
    Its folder is: $dir

    This is a REVERSE-ENGINEERING project (kind=re in .vibe-project): he wants to take an
    existing program or game apart. The \"Reverse-engineering projects\" section of
    ../CLAUDE.md applies on top of everything else there. REA's MCP tools and skill, Ghidra,
    the compilers and the rest of the toolchain are already loaded in this session.

    It is brand new. The folder is a git repo on main with one commit: the empty project
    layout (target/, notes/, evidence/, recomp/, tests/), a .gitignore that keeps target/
    out of git, and a CLAUDE.md whose two sections are still to be filled in. Nothing has
    been analysed yet.

    Start by asking him, in plain English, what program or game this is and where the file
    is on his computer (most likely Downloads). Copy it into target/ yourself and record its
    SHA-256. Then ask him what he wants out of it — to see how it works, to change
    something about it, or to rebuild it — because that part is his call. Fill in the two
    sections of CLAUDE.md, then begin."
      elif [ "$kind" = game ]; then
        launch "$dir" game "The game is called: $title
    Its folder is: $dir

    This is a GAME project (kind=game in .vibe-project): he wants to make his own game.
    The \"Game projects\" section of ../CLAUDE.md applies on top of everything else there.
    The gamedev skills (start with gamedev:router) and the game engines are already loaded
    in this session.

    It is brand new. The folder is a git repo on main with one commit: empty assets/ and
    docs/ folders, a .gitignore, and a CLAUDE.md whose two sections are still to be filled
    in. No engine has been picked and nothing has been built yet.

    Start by asking him, in plain English, what kind of game he has in mind: what you do in
    it, what it looks like, and any game it should feel like. That part is his call — ask a
    couple of short questions, not a questionnaire. Then pick the engine yourself (Godot
    unless there is a reason not to), fill in the two sections of CLAUDE.md, and build the
    smallest version he can actually play. Check it runs and look at a screenshot before
    you hand it over, then tell him how to start it and which keys to press."
      else
        launch "$dir" app "The app is called: $title
    Its folder is: $dir

    It is brand new. The folder is a git repo on main with one commit, a .gitignore, a
    CLAUDE.md whose first two sections are still to be filled in, and an empty shell= line
    in .vibe-project. Nothing has been built yet.

    Start by asking him what he wants the app to do and what he wants it to look like — that
    part is his call. Then pick the language yourself, write .envrc for the matching dev
    shell, record that shell on the shell= line of .vibe-project, allow direnv on his
    behalf, fill in the two sections of CLAUDE.md, and build a first version he can try."
      fi
    }

    # --- existing project ------------------------------------------------------

    open_project() {
      local dir="$1" title="$2" kind choice noun
      kind=$(marker_field "$dir" kind)
      case "$kind" in re|game) ;; *) kind=app ;; esac
      case "$kind" in re) noun="project" ;; game) noun="game" ;; *) noun="app" ;; esac
      prepare_dir "$dir"

      echo
      echo "What do you want to do with $title?"

      local -a labels=() actions=()
      if [ "$SESSIONS" -gt 0 ]; then
        labels+=("Pick up where you left off")          ; actions+=(continue)
        labels+=("Start a fresh chat about this $noun") ; actions+=(fresh)
        labels+=("Look through your older chats")       ; actions+=(resume)
      else
        # `claude -c` errors out where there is no saved chat, so it must not be offered.
        labels+=("Start working on it")                 ; actions+=(fresh)
      fi

      local i
      for i in "''${!labels[@]}"; do
        printf "  %d) %s\n" $((i + 1)) "''${labels[$i]}"
      done
      echo

      read -rp "Enter a number (or q to cancel): " choice
      [ "$choice" = q ] && { echo "Cancelled — nothing started."; exit 0; }
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] \
           || [ "$choice" -gt "''${#labels[@]}" ]; then
        echo "That wasn't a valid choice. Nothing started."
        exit 1
      fi

      case "''${actions[$((choice - 1))]}" in
        continue)
          run_claude "$dir" "$kind" -c
          ;;
        resume)
          run_claude "$dir" "$kind" -r
          ;;
        fresh)
          if [ "$kind" = re ]; then
            launch "$dir" re "The project is called: $title
    Its folder is: $dir

    This is a REVERSE-ENGINEERING project (kind=re in .vibe-project). The
    \"Reverse-engineering projects\" section of ../CLAUDE.md applies on top of everything
    else there. REA's MCP tools and skill and the toolchain are already loaded in this
    session.

    It already exists. Read its CLAUDE.md, notes/ and anything in docs/ before you do
    anything else, and look at the git log to see where it was left. Then tell him in a
    sentence or two where things stand, and ask him what he wants to do next."
          elif [ "$kind" = game ]; then
            launch "$dir" game "The game is called: $title
    Its folder is: $dir

    This is a GAME project (kind=game in .vibe-project). The \"Game projects\" section of
    ../CLAUDE.md applies on top of everything else there. The gamedev skills and the
    engines are already loaded in this session.

    It already exists. Read its CLAUDE.md and anything in docs/ before you do anything
    else, and look at the git log to see where it was left. Then ask him what he wants to
    change or add next — or whether something in it doesn't feel right when he plays it."
          else
            launch "$dir" app "The app is called: $title
    Its folder is: $dir

    This app already exists. Read its CLAUDE.md and anything in docs/ before you do anything
    else, and look at the git log to see where it was left. Then ask him what he wants to
    change or add next."
          fi
          ;;
      esac
    }

    pick_project() {
      local -a dirs=() titles=() labels=()
      local m d t s k label
      for m in "$PROJECTS_DIR"/*/.vibe-project; do
        [ -f "$m" ] || continue
        d=$(dirname "$m")
        t=$(marker_field "$d" title); [ -n "$t" ] || t=$(basename "$d")
        s=$(marker_field "$d" shell)
        k=$(marker_field "$d" kind)
        label="$t"
        if [ "$k" = re ]; then
          label="$label  (taking apart)"
        elif [ "$k" = game ]; then
          label="$label  (game)"
        elif [ -n "$s" ]; then
          label="$label  (''${s#vibe-})"
        fi
        dirs+=("$d"); titles+=("$t"); labels+=("$label")
      done

      if [ "''${#dirs[@]}" -eq 0 ]; then
        echo
        echo "You don't have any apps yet — let's start your first one."
        new_project app
        return
      fi

      local i choice
      echo
      echo "Which one?"
      for i in "''${!labels[@]}"; do
        printf "  %d) %s\n" $((i + 1)) "''${labels[$i]}"
      done
      echo

      read -rp "Enter a number (or q to cancel): " choice
      [ "$choice" = q ] && { echo "Cancelled — nothing started."; exit 0; }
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] \
           || [ "$choice" -gt "''${#dirs[@]}" ]; then
        echo "That wasn't a valid choice. Nothing started."
        exit 1
      fi

      open_project "''${dirs[$((choice - 1))]}" "''${titles[$((choice - 1))]}"
    }

    # --- top level -------------------------------------------------------------

    shopt -s nullglob
    EXISTING=("$PROJECTS_DIR"/*/.vibe-project)
    shopt -u nullglob

    # Nothing yet and nothing else to offer? Skip the menu and get him straight into his
    # first app. With reverse engineering or games available there is a real choice to make,
    # so the menu is shown even then.
    if [ "''${#EXISTING[@]}" -eq 0 ] && [ -z "$RE_LAUNCHER" ] && [ -z "$GD_LAUNCHER" ]; then
      echo "This is where you build your own apps. You don't have any yet."
      new_project app
      exit 0
    fi

    declare -a TOP_LABELS=() TOP_ACTIONS=()
    if [ "''${#EXISTING[@]}" -gt 0 ]; then
      TOP_LABELS+=("Work on something you already started"); TOP_ACTIONS+=(pick)
    fi
    TOP_LABELS+=("Start a brand new app"); TOP_ACTIONS+=(new-app)
    if [ -n "$GD_LAUNCHER" ]; then
      TOP_LABELS+=("Make a game of your own"); TOP_ACTIONS+=(new-game)
    fi
    if [ -n "$RE_LAUNCHER" ]; then
      TOP_LABELS+=("Take apart a program or game to see how it works (reverse engineering)")
      TOP_ACTIONS+=(new-re)
    fi

    echo
    echo "What do you want to do?"
    for i in "''${!TOP_LABELS[@]}"; do
      printf "  %d) %s\n" $((i + 1)) "''${TOP_LABELS[$i]}"
    done
    echo

    read -rp "Enter a number (or q to cancel): " TOP
    [ "$TOP" = q ] && { echo "Cancelled — nothing started."; exit 0; }
    if ! [[ "$TOP" =~ ^[0-9]+$ ]] || [ "$TOP" -lt 1 ] \
         || [ "$TOP" -gt "''${#TOP_LABELS[@]}" ]; then
      echo "That wasn't a valid choice. Nothing started."
      exit 1
    fi

    case "''${TOP_ACTIONS[$((TOP - 1))]}" in
      pick) pick_project ;;
      new-app) new_project app ;;
      new-re) new_project re ;;
      new-game) new_project game ;;
    esac
  '';
in
{
  options.customConfig.programs.vibeProjects = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install the `vibe` command: a numbered-menu front door for the user's own
        "vibe coded" app projects, each a git repo under `dir` that is local-only unless
        pushed to a GitHub repo on the user's own account.

        Intended for a non-technical user. The command never asks a technical question —
        the seeded Claude session interviews him about what the app should do and look
        like, then picks the language itself.

        The rules for a session in a project are installed one directory above the
        projects by modules/home-manager/development/vibe-projects.nix, so that resumed
        sessions (which carry no prompt) get them too.

        This expects `programs.claudeCode.enable` as well: `vibe` launches `sudo claude`
        either way, but the chown hooks that keep the user able to edit his own files come
        from that module.
      '';
    };

    dir = mkOption {
      type = types.str;
      default = "${cfg.user.home}/projects";
      description = ''
        Container directory for the projects. A single directory rather than one per
        project directly in `$HOME` so that `programs.claudeCode.extraChownPaths` covers
        every present and future project with one entry, and so that one CLAUDE.md above
        them can carry the rules for all of them.
      '';
    };

    shells = mkOption {
      type = types.listOf types.str;
      default = [ "vibe-python" "vibe-web" ];
      description = ''
        Names of the shared dev shells a project may point its `.envrc` at. Listed in the
        rules file so a session knows what it can choose from; they must exist as flake
        outputs, which means being enabled on gaming-pc (see
        modules/nixos/development/vibe-python.nix).
      '';
    };
  };

  config = lib.mkIf vibeCfg.enable {
    environment.systemPackages = [ vibeCmd ];

    # Claude writes these projects as root. Covering the container directory here rather
    # than in the host file means the chown hooks pick up every new project automatically.
    customConfig.programs.claudeCode.extraChownPaths = [ projectsDir ];
  };
}
