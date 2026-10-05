# ~/nixos-config/modules/nixos/programs/vibe-projects.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig;
  vibeCfg = cfg.programs.vibeProjects;

  userName = cfg.user.name;
  userEmail = cfg.user.email;
  configDir = "${cfg.user.home}/nixos-config";
  projectsDir = vibeCfg.dir;

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
    the app looks and behaves, this project's git repo is his to commit to `main` freely and
    has no remote, and anything needing the NixOS config at ${configDir} should be handed
    back to him to run `ccn` for rather than done from here.
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
    # name, shell= is the dev shell Claude picked for it (empty until it has). Read with
    # sed and never sourced — the title is arbitrary text he typed.
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

    launch() {
      # launch <dir> <extra prompt text>
      local dir="$1" extra="$2" prompt
      prompt="$(cat "$SESSION_RULES")

    --- THIS SESSION ---
    $extra"
      cd "$dir" || exit 1
      exec sudo claude "$prompt"
    }

    # --- new project -----------------------------------------------------------

    new_project() {
      local title slug dir
      echo
      read -rp "What do you want to call your app? " title
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
        echo "You already have an app in $dir."
        echo "Pick a different name, or run vibe again and choose the app you already started."
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

      printf 'title=%s\nslug=%s\nshell=\n' "$title" "$slug" > "$dir/.vibe-project"
      # install, not cp: store files are read-only and Claude has to be able to edit these.
      install -m 0644 "${projectGitignore}" "$dir/.gitignore"
      { printf '# %s\n\n' "$title"; cat "${projectClaudeMd}"; } > "$dir/CLAUDE.md"
      chmod 0644 "$dir/CLAUDE.md"

      git -C "$dir" add -A
      git -C "$dir" commit -q -m "chore: start $title"

      prepare_dir "$dir"
      echo "Done. Starting Claude on it now."
      launch "$dir" "The app is called: $title
    Its folder is: $dir

    It is brand new. The folder is a git repo on main with one commit, a .gitignore, a
    CLAUDE.md whose first two sections are still to be filled in, and an empty shell= line
    in .vibe-project. Nothing has been built yet.

    Start by asking him what he wants the app to do and what he wants it to look like — that
    part is his call. Then pick the language yourself, write .envrc for the matching dev
    shell, record that shell on the shell= line of .vibe-project, allow direnv on his
    behalf, fill in the two sections of CLAUDE.md, and build a first version he can try."
    }

    # --- existing project ------------------------------------------------------

    open_project() {
      local dir="$1" title="$2" choice
      prepare_dir "$dir"

      echo
      echo "What do you want to do with $title?"

      local -a labels=() actions=()
      if [ "$SESSIONS" -gt 0 ]; then
        labels+=("Pick up where you left off")       ; actions+=(continue)
        labels+=("Start a fresh chat about this app"); actions+=(fresh)
        labels+=("Look through your older chats")    ; actions+=(resume)
      else
        # `claude -c` errors out where there is no saved chat, so it must not be offered.
        labels+=("Start working on it")              ; actions+=(fresh)
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
          cd "$dir" || exit 1
          exec sudo claude -c
          ;;
        resume)
          cd "$dir" || exit 1
          exec sudo claude -r
          ;;
        fresh)
          launch "$dir" "The app is called: $title
    Its folder is: $dir

    This app already exists. Read its CLAUDE.md and anything in docs/ before you do anything
    else, and look at the git log to see where it was left. Then ask him what he wants to
    change or add next."
          ;;
      esac
    }

    pick_project() {
      local -a dirs=() titles=() shells=()
      local m d t s
      for m in "$PROJECTS_DIR"/*/.vibe-project; do
        [ -f "$m" ] || continue
        d=$(dirname "$m")
        t=$(marker_field "$d" title); [ -n "$t" ] || t=$(basename "$d")
        s=$(marker_field "$d" shell)
        dirs+=("$d"); titles+=("$t"); shells+=("$s")
      done

      if [ "''${#dirs[@]}" -eq 0 ]; then
        echo
        echo "You don't have any apps yet — let's start your first one."
        new_project
        return
      fi

      local i label choice
      echo
      echo "Which app?"
      for i in "''${!titles[@]}"; do
        label="''${titles[$i]}"
        [ -n "''${shells[$i]}" ] && label="$label  (''${shells[$i]#vibe-})"
        printf "  %d) %s\n" $((i + 1)) "$label"
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

    # Nothing yet? Skip the menu entirely and get him straight into his first app.
    shopt -s nullglob
    EXISTING=("$PROJECTS_DIR"/*/.vibe-project)
    shopt -u nullglob

    if [ "''${#EXISTING[@]}" -eq 0 ]; then
      echo "This is where you build your own apps. You don't have any yet."
      new_project
      exit 0
    fi

    echo
    echo "What do you want to do?"
    echo "  1) Work on an app you already started"
    echo "  2) Start a brand new app"
    echo

    read -rp "Enter a number (or q to cancel): " TOP
    case "$TOP" in
      q) echo "Cancelled — nothing started."; exit 0 ;;
      1) pick_project ;;
      2) new_project ;;
      *) echo "That wasn't a valid choice. Nothing started."; exit 1 ;;
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
        "vibe coded" app projects, each a local-only git repo under `dir`.

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
