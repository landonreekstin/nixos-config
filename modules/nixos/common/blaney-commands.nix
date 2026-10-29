# ~/nixos-config/modules/nixos/common/blaney-commands.nix
{ config, pkgs, lib, ... }:

# insideabush's (blaney-pc) own commands: his deterministic, non-technical-friendly helpers
# and the `vibe` config chat. Gated to the insideabush user, so this module is a no-op on
# every other host.
#
# NEW BLANEY COMMANDS GO HERE — not in ./commands.nix, which every host shares. Add each
# one to the systemPackages list below, and give every user-facing one a line in
# `blaney-help` at the bottom (his command index). See docs/hosts/blaney-pc.md#his-commands.
let
  cfg = config.customConfig;
  nixosConfigDir = "${cfg.user.home}/nixos-config"; # Path to the cloned Git repository
  userName = cfg.user.name;
  userGroup = config.users.users.${userName}.group;

  # --- blaney-pc config chat (in `vibe`) -----------------------------------------
  # Appended to the system prompt of every config chat `vibe` opens — new, continued or
  # picked from the list — so the blaney-pc rules are in force from the first turn instead of
  # depending on the session reading docs/hosts/blaney-pc.md. A store file `cat`ed by the
  # script, never a heredoc, so the backticks below are just text. Keep in sync with
  # docs/hosts/blaney-pc.md (and the blaney-todo preface prompts further down).
  # The Glade's Claude panel: its hooks and the rules telling Claude to use it live with the
  # rest of the glade desktop (hyprland/desktops/glade/claude-panel.nix).
  gladePanel = import ../../home-manager/hyprland/desktops/glade/claude-panel.nix { inherit pkgs; customConfig = cfg; };
  gladeHooks = gladePanel.hooks;
  gladeStatus = gladePanel.status;
  notesList = "${cfg.user.home}/notes-list.txt"; # blaney-pc `add-notes` / `work-notes`

  ccnRules = pkgs.writeText "ccn-blaney-rules.md" ''
    # blaney-pc config session (opened from `vibe`)

    You are working in the NixOS config at ${nixosConfigDir} on blaney-pc, for its
    user ${userName} (Blaney). The full rules are in docs/hosts/blaney-pc.md and CLAUDE.md
    in that repo; this is the binding summary of them. Where CLAUDE.md's general workflow
    conflicts with this, this wins.

    ## Who you are working with

    - He is not technical: no Linux, no Nix, no code. Never ask him to make a technical or
      architectural decision, and never ask him to run a command you can run yourself. Run
      `rebuild`, `chown`, git and everything else yourself.
    - He DOES decide how things look and behave: colours, layout, what a feature does. For
      a feature request, ask him about that first, then do all the rest on your own. For a
      bug, just fix it and give him a "does this look right?" check.
    - Keep every message short and plain. Explain any technical word the moment you use
      it. Give next steps as one plain sentence ("Tell me if the wallpaper changed").

    ## Git rules (strict)

    - Every branch for his work starts with `blaney/` (e.g. `blaney/fix-wifi`). Reuse the
      existing `blaney/` branch when continuing the same piece of work.
    - Never commit or push to `main`, or to any branch that does not start with `blaney/`.
      Never merge a `blaney/` branch into anything else.
    - When he confirms the change works, open a PR with `gh pr create` and stop. Lando
      merges it; you never do.
    - Never discard, delete or overwrite a branch, commit or stash without asking him first.

    ## Workflow

    Branch, edit, `chown -R ${userName}:${userGroup} ${nixosConfigDir}`, `rebuild` (or
    `rebuild-test` for a bigger change, so he can try it before it sticks), have him confirm
    it works, then commit and open the PR.

    ## His commands

    Every command made for him lives in modules/nixos/common/blaney-commands.nix. Add a new
    one or change an existing one there, never in modules/nixos/common/commands.nix (every
    machine shares that file). Give each new command a line in `blaney-help`, and if you
    rename one, leave the old name behind as a short command that points him to the new one.

    ## Catch up with GitHub first — every time work starts or continues

    Do this before anything else: at the start of a new chat, at the start of a resumed
    chat (before answering his first message there), and again whenever he comes back after
    a break or moves on to a new piece of work in the same chat. Tell him in one sentence
    that you are getting the latest updates first.

    1. `git fetch --prune origin`. If that fails (no internet), tell him in one sentence and
       carry on with what is on the machine.
    2. Look at `git branch --show-current`, `git status --porcelain` and `git stash list`.
       Uncommitted changes are his unfinished work and are never thrown away. If a step
       below needs a clean tree, commit them to the current `blaney/` branch as a WIP commit
       or `git stash push -u -m "ccn:<branch>"`, and put them back afterwards; tell him in
       one sentence where his work is. Mention any older stashes so they are not forgotten.
    3. Then, depending on the branch:
       - `main`: `git merge --ff-only origin/main`.
       - a `blaney/` branch:
         a. If its PR has already been merged (`gh pr list --head <branch> --state merged`),
            that work is finished: switch to `main`, catch it up, and put any new work on a
            fresh `blaney/` branch.
         b. If GitHub has commits on this branch that the checkout does not
            (`git rev-list --count HEAD..@{upstream}` is not 0), bring them in with
            `git pull --ff-only`, or rebase onto them if the two have diverged.
         c. If `git rev-list --count HEAD..origin/main` is not 0, the branch is behind
            main: `git rebase origin/main`. Resolve conflicts yourself when the right answer
            is clear; when it is not, `git rebase --abort`, leave the branch as it was, and
            tell him in one sentence. After a successful rebase of a branch that is on
            GitHub, `git push --force-with-lease` (allowed: it is a `blaney/` branch, never
            `main`).
       - any other branch (one of Lando's): do not commit there. Switch to `main`, or to the
         `blaney/` branch the work belongs on, and catch that up instead.
    4. In a new chat about new work, branch off the caught-up `main`, unless what he asks
       for is clearly a continuation of the `blaney/` branch that is checked out.
    5. If any of this changed what is checked out, `chown` and `rebuild` before carrying on,
       so his computer is running the up-to-date config. If that rebuild fails, fixing it
       (on a `blaney/` branch) becomes the first job.
    6. Check his open PRs for comments from Lando (GitHub user `landonreekstin`):
       `gh pr list --author @me --state open`, then for each one
       `gh pr view <N> --json comments,reviews,reviewDecision` plus the line-by-line review
       comments from `gh api repos/landonreekstin/nixos-config/pulls/<N>/comments`.
       A comment from Lando is still open if nothing from this account was posted on the PR
       after it saying it was dealt with.
       - On the `blaney/` branch that is checked out: Lando's open comments come before
         anything new. Tell him in one sentence that Lando asked for changes and what they
         are, then make them with the usual workflow (edit, `chown`, `rebuild`, he confirms
         it works, commit, `git push`, which updates the PR by itself). Lando's requested
         changes and fixes are not optional, but if one changes how something looks or
         behaves, tell him in a sentence before you do it. If a comment is a question
         rather than a request, answer it on the PR.
       - Once a comment is dealt with, reply on the PR with `gh pr comment <N>` saying
         briefly what changed (and in which commit), so Lando can see it and the next
         catch-up knows it is handled. If you could not do something, say why in that
         reply instead of leaving it unanswered.
       - Open comments on a PR for a different `blaney/` branch: tell him in one sentence
         and offer to switch to that branch to deal with them first.

    ## His own apps' pins are releases: never bump one along the way

    His apps packaged here from his GitHub (`pkgs/glade`, `pkgs/r62d`, anything with
    `owner = "cblaney00"`) are built on this computer from his project folders in
    ~/projects (`localApps` in hosts/blaney-pc/apps.nix). A plain `rebuild` already
    installs his newest version, whatever the pin says. The pin (`rev`, `hash`, `version`)
    is only what Lando's machines get.

    - **Never change a pin to get a change onto this computer**, and never put a pin change
      in a branch that does anything else, cherry-picked or not. Every past PR that did
      ended in merge conflicts.
    - A pin moves only for a **release**: he says he wants Lando to have the current version
      of an app ("release my glade app to Lando"). The app's project must be pushed to
      GitHub first; pin the commit that is on GitHub's `main`.
    - A release is its own PR, one app per PR, on `blaney/release-<app>`, cut fresh from
      `origin/main` (`git switch -C blaney/release-<app> origin/main`), touching only
      `pkgs/<app>/` (plus docs/companion-repos.md if it needs a note). Get the hash with
      the `lib.fakeHash` build. Rebuild is not needed to verify it on this computer (it
      builds from the folder anyway); build the pinned package instead:
      `nix build --impure --no-link --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/<app> { }'`.
    - If a release PR for that app is already open, do not open a second one: re-cut the
      same branch from `origin/main` with the new pin, `git push --force-with-lease`, and
      update the PR's title and body. Do the same instead of rebasing whenever a release
      branch is behind `main` or a catch-up rebase of it conflicts: a release branch is
      never worth resolving, only re-cutting.
    - A config change that needs a newer version of his app than the pin (it uses
      something new in the app) still does not bump the pin. Say in its PR body that it
      needs the release PR for that app merged first.

    ${gladePanel.ccnRules}'';

  # Claude runs as `sudo claude`, so its saved chats live under /root (0700) and the menu,
  # running as the user, cannot look for itself. Prints the newest chat that has a user
  # message in it. Chats with no user message are skipped: `claude remote-control` drops
  # an empty <uuid>.jsonl into the project's history every time its server starts, and
  # resuming one of those is a blank session (the same reason the old `ccnc` did this).
  # Fails soft to "no chats".
  ccnLastSession = pkgs.writeShellScript "ccn-last-session" ''
    set -u
    key=$(printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g')
    cd "/root/.claude/projects/$key" 2>/dev/null || exit 0
    for f in $(ls -t -- *.jsonl 2>/dev/null); do
      grep -q '"type":"user"' "$f" && { echo "''${f%.jsonl}"; exit 0; }
    done
    exit 0
  '';
  # The blaney-pc config chat: one numbered menu for a new chat (typed straight in here),
  # the last chat, or an older one, every one of them opened with the blaney-pc rules
  # appended to the system prompt (ccnRules above). Not a command of its own: it is an
  # entry in the `vibe` menu (handed over through programs.vibeProjects.configChat below),
  # because everything Blaney does with Claude starts at `vibe`. Everywhere else
  # ccn/ccnc/ccnr are plain shell functions (modules/home-manager/system/bash.nix).
  configChat = pkgs.writeShellScript "blaney-config-chat" ''
    #!${pkgs.stdenv.shell}
    set -uo pipefail
    REPO="${nixosConfigDir}"
    cd "$REPO" 2>/dev/null || { echo "Can't find your config folder at $REPO — tell Lando."; exit 1; }
    RULES="$(cat ${ccnRules})"

    # One password prompt here also covers the `sudo claude` below.
    LAST=$(sudo ${ccnLastSession} "$(pwd -P)" 2>/dev/null) || LAST=""

    new_chat() {
      local request
      echo
      echo "What do you want Claude to do? Type it in your own words and press Enter."
      echo "(Or just press Enter and Claude will ask you.)"
      read -rep "> " request
      if [ -z "''${request//[[:space:]]/}" ]; then
        request="(New chat from vibe, nothing typed yet. Catch up with GitHub first, as your instructions say, then ask him what he wants to work on.)"
      else
        request="(New chat from vibe. Catch up with GitHub first, as your instructions say, then get on with this.)

    $request"
      fi
      exec sudo claude --settings ${gladeHooks} --append-system-prompt "$RULES" "$request"
    }

    # Nothing to go back to? Skip the menu.
    [ -n "$LAST" ] || new_chat

    echo
    echo "What do you want to do?"
    echo "  1) Start a new chat"
    echo "  2) Pick up where you left off"
    echo "  3) Look through your older chats"
    echo
    read -rp "Enter a number (or q to cancel): " CHOICE

    # A resumed chat renders its system prompt fresh rather than replaying the one it was
    # started with: chats from before this command have no rules in theirs at all, and
    # older ones would keep a stale copy after the rules change.
    RESUME=(--settings ${gladeHooks} --append-system-prompt "$RULES" --system-prompt-snapshot off)
    case "$CHOICE" in
      1) new_chat ;;
      2) exec sudo claude "''${RESUME[@]}" -r "$LAST" \
           "(He reopened this chat from vibe. Catch up with GitHub first, as your instructions say, then remind him in a sentence or two where things were left and ask what is next.)" ;;
      3) exec sudo claude "''${RESUME[@]}" -r ;;
      q) echo "Cancelled — nothing started."; exit 0 ;;
      *) echo "That wasn't a valid choice. Nothing started."; exit 1 ;;
    esac
  '';

in
{
  config = lib.mkIf (cfg.user.name == "insideabush") {
    # Do NOT gate anything here on updateCmdPermission (it is false on blaney-pc).
    environment.systemPackages = [
      # Deprecated alias: `sync` was renamed to `update` (it shadowed coreutils' sync).
      # Kept only here so insideabush's muscle memory and older runbooks keep working —
      # it points at the new name, then does the update anyway rather than leaving him
      # stuck. Delete once the new name has stuck.
      (pkgs.writeShellScriptBin "sync" ''
        #!${pkgs.stdenv.shell}
        echo "Heads up: 'sync' is now called 'update'. Use 'update' from now on."
        echo "Running 'update' for you..."
        echo
        exec update
      '')

      # `ccn` (and ccnc/ccnr below) moved into `vibe` as its "Change or fix something on
      # your computer" entry. Kept only so muscle memory still lands somewhere useful, like
      # `sync` above; delete once `vibe` has stuck.
      (pkgs.writeShellScriptBin "ccn" ''
        #!${pkgs.stdenv.shell}
        echo "Heads up: 'ccn' is now part of 'vibe' — choose \"Change or fix something on your computer\"."
        exec vibe
      '')
      (pkgs.writeShellScriptBin "ccnc" ''
        #!${pkgs.stdenv.shell}
        echo "Heads up: 'ccnc' is now part of 'vibe' — choose \"Change or fix something on your computer\", then \"Pick up where you left off\"."
        exec vibe
      '')
      (pkgs.writeShellScriptBin "ccnr" ''
        #!${pkgs.stdenv.shell}
        echo "Heads up: 'ccnr' is now part of 'vibe' — choose \"Change or fix something on your computer\", then \"Look through your older chats\"."
        exec vibe
      '')

      (pkgs.writeShellScriptBin "branch-switch" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        REPO="${nixosConfigDir}"
        cd "$REPO"

        echo "Fetching latest branches..."
        git fetch --prune origin || true
        CURRENT=$(git rev-parse --abbrev-ref HEAD)

        # Build a unique branch list (local + origin/*), with main first.
        mapfile -t REMOTES < <(git branch -r --format='%(refname:short)' \
          | grep -v 'origin/HEAD' | sed 's#^origin/##')
        mapfile -t LOCALS  < <(git branch --format='%(refname:short)')
        BRANCHES=(main)
        while read -r b; do
          [ "$b" = main ] && continue
          BRANCHES+=("$b")
        done < <(printf '%s\n' "''${REMOTES[@]}" "''${LOCALS[@]}" | sort -u)

        echo
        echo "Which branch do you want to try?"
        for i in "''${!BRANCHES[@]}"; do
          mark=""
          [ "''${BRANCHES[$i]}" = "$CURRENT" ] && mark="  (current)"
          printf "  %d) %s%s\n" $((i + 1)) "''${BRANCHES[$i]}" "$mark"
        done
        echo

        read -rp "Enter a number (or q to cancel): " CHOICE
        [ "$CHOICE" = q ] && { echo "Cancelled — nothing changed."; exit 0; }
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] \
             || [ "$CHOICE" -gt "''${#BRANCHES[@]}" ]; then
          echo "That wasn't a valid choice. Nothing changed."
          exit 1
        fi
        TARGET="''${BRANCHES[$((CHOICE - 1))]}"
        [ "$TARGET" = "$CURRENT" ] && { echo "You're already on $TARGET."; exit 0; }

        # Save the current working changes, tagged with the branch they came from.
        if [ -n "$(git status --porcelain)" ]; then
          echo "Saving your current changes (from $CURRENT)..."
          git stash push -u -m "branch-switch:$CURRENT"
          echo "Saved — switch back to $CURRENT later to get them back."
        fi

        echo "Switching to $TARGET..."
        if git show-ref --verify --quiet "refs/heads/$TARGET"; then
          git checkout "$TARGET"
        else
          git checkout -b "$TARGET" --track "origin/$TARGET"
        fi
        git pull --ff-only 2>/dev/null || true   # best-effort latest

        # Offer to restore a stash previously saved for THIS branch.
        MATCH=$(git stash list | grep -F "branch-switch:$TARGET" | head -1 | cut -d: -f1 || true)
        if [ -n "$MATCH" ]; then
          echo
          echo "You have saved changes from the last time you were on $TARGET."
          read -rp "Restore them now? (y/N): " R
          if [[ "$R" =~ ^[Yy]$ ]]; then
            if git stash pop "$MATCH"; then
              echo "Restored."
            else
              echo "Couldn't auto-restore (conflict); your changes are still saved. Run smart-rebuild if you get stuck."
            fi
          else
            echo "Left them saved."
          fi
        fi

        echo
        echo "Rebuilding for $TARGET..."
        if rebuild; then
          echo "Done — you're now on $TARGET."
        else
          echo
          echo "The rebuild for $TARGET failed."
          echo "  To get back to a working system:   smart-rebuild"
          echo "  To try to fix this branch:          claude-rebuild-failed"
          exit 1
        fi
      '')

      # Hand a broken system to Claude: `claude-rebuild-failed` fixes the failed rebuild on
      # the current branch; `smart-rebuild` saves any work in progress and gets him back to
      # a working `main`. branch-switch and the rebuild-shutdown notice point him at both.
      (pkgs.writeShellScriptBin "claude-rebuild-failed" ''
        #!${pkgs.stdenv.shell}
        cd "${nixosConfigDir}" && exec sudo claude "A NixOS rebuild failed. Run \`rebuild\` to reproduce the error, diagnose the cause, and fix it. Then create a PR with the fix. This is a blaney-pc session: follow all blaney-pc rules in CLAUDE.md (branch prefix blaney/, never push to main). Keep all explanations brief and simple — the user is non-technical and does not know Nix, Linux, or code, so do not rely on their knowledge or ask them to make technical decisions. Take full ownership of every technical decision and recommendation and just get the system working. Lando reviews and approves the PR, so make the best call and proceed."
      '')
      (pkgs.writeShellScriptBin "smart-rebuild" ''
        #!${pkgs.stdenv.shell}
        cd "${nixosConfigDir}" && exec sudo claude "Do a smart rebuild. This is a blaney-pc session — follow all blaney-pc rules in CLAUDE.md (branch prefix blaney/, never push to main), keep every explanation brief and simple for a non-technical user, and take full ownership of every technical decision. Never discard, delete, or overwrite any branch, commit, or stash without asking the user first. Steps: 1) Run git fetch and git stash list, and note the current branch. 2) Check for any work-in-progress (uncommitted or unpushed) changes on the current branch; if there are any, decide the best way to preserve them — stash them, commit them to the current branch, or open a WIP PR — and tell the user in one sentence what you did and where their work now lives. If git stash list showed pre-existing saved changes from an earlier session, mention them so they aren't forgotten. 3) Switch to main and pull the latest. 4) Run \`rebuild\`. 5) If the rebuild fails, diagnose and fix the error, rebuild again until it succeeds, and open a PR with the fix. 6) After the rebuild succeeds, ask the user whether they want to go back to what they were working on before (switch back to their WIP branch, or restore a saved stash including any pre-existing one) or stay on the latest main, then do whatever they choose. Lando reviews and approves all PRs, so make the best call and proceed."
      '')

      (pkgs.writeShellScriptBin "blaney-todo" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        REPO="${nixosConfigDir}"
        if [ ! -d "$REPO/.git" ]; then
          echo "Can't find your config folder at $REPO — tell Lando."
          exit 1
        fi
        cd "$REPO" || exit 1

        RUNBOOK_DIR="docs/runbooks/blaney"

        echo "Checking for new tasks from Lando..."
        git fetch --quiet origin main 2>/dev/null \
          || echo "(couldn't reach GitHub — showing the tasks I already know about)"

        # Pending tasks are the markdown files Lando has pushed to main. The README
        # in that folder is the how-to for writing them, not a task.
        mapfile -t FILES < <(git ls-tree --name-only origin/main "$RUNBOOK_DIR/" 2>/dev/null \
          | grep '\.md$' | grep -v '/README\.md$')

        if [ "''${#FILES[@]}" -eq 0 ]; then
          echo
          echo "No tasks right now — Lando hasn't left you anything to do."
          exit 0
        fi

        # Menu entry = the file's first markdown heading, minus any "Runbook:" prefix.
        TITLES=()
        for f in "''${FILES[@]}"; do
          t=$(git show "origin/main:$f" 2>/dev/null | grep -m1 '^# ' \
            | sed -e 's/^# *//' -e 's/^[Rr]unbook: *//')
          [ -z "$t" ] && t=$(basename "$f" .md)
          TITLES+=("$t")
        done

        # `--unattended` (what the shutdown dialog runs) skips the "how?" question below and
        # goes straight to the walk-away mode.
        UNATTENDED=0
        [ "''${1:-}" = "--unattended" ] && UNATTENDED=1

        # Runbooks a walk-away run already finished stay in the menu until Lando merges the PR
        # and deletes them; blaney-todo-unattended records them here so they can be labelled.
        DONE_FILE="$HOME/.local/state/blaney-todo-done"

        echo
        echo "What do you want Claude to work on?"
        for i in "''${!TITLES[@]}"; do
          mark=""
          grep -qxF "''${FILES[$i]}" "$DONE_FILE" 2>/dev/null && mark="  (done, waiting for Lando)"
          printf "  %d) %s%s\n" $((i + 1)) "''${TITLES[$i]}" "$mark"
        done
        echo

        read -rp "Enter a number (or q to cancel): " CHOICE
        [ "$CHOICE" = q ] && { echo "Cancelled — nothing started."; exit 0; }
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] \
             || [ "$CHOICE" -gt "''${#FILES[@]}" ]; then
          echo "That wasn't a valid choice. Nothing started."
          exit 1
        fi
        TARGET="''${FILES[$((CHOICE - 1))]}"
        TITLE="''${TITLES[$((CHOICE - 1))]}"

        if [ "$UNATTENDED" -eq 0 ]; then
          echo
          echo "How do you want to do it?"
          echo "  1) Work on it together with Claude"
          echo "  2) Let Claude do it on its own, then shut the PC down (you can walk away)"
          echo
          read -rp "Enter a number (or q to cancel): " MODE
          case "$MODE" in
            1) ;;
            2) UNATTENDED=1 ;;
            q) echo "Cancelled — nothing started."; exit 0 ;;
            *) echo "That wasn't a valid choice. Nothing started."; exit 1 ;;
          esac
        fi

        if [ "$UNATTENDED" -eq 1 ]; then
          echo
          echo "Claude will do \"$TITLE\" by itself, send it to Lando to look at,"
          echo "then get the latest updates and shut the PC down."
          echo "Type your password below, then you can walk away."
          echo
          exec sudo blaney-todo-unattended "$TARGET" "$TITLE"
        fi

        echo
        echo "Starting Claude on: $TITLE"
        echo

        # Preface prompt — keep in sync with the blaney-pc rules in CLAUDE.md (and with the
        # walk-away version in blaney-todo-unattended below).
        # No backticks in here: the heredoc is unquoted so $TARGET expands.
        PROMPT=$(cat <<EOF
        Work on the runbook at $TARGET. Read it first with: git show origin/main:$TARGET
        (it may not exist on the branch you are currently on). Then carry out the task it
        describes end to end. This is a blaney-pc session — follow all blaney-pc rules in
        CLAUDE.md: branch prefix blaney/, never push to main, never merge into a branch that
        does not start with blaney/. Keep every explanation brief and simple; the user is
        non-technical and does not know Nix, Linux, or code, so never ask him to make a
        technical decision and never ask him to run a command you can run yourself. Take full
        ownership of every technical choice. He DOES decide how things look and behave — if
        the runbook leaves the visual or user-facing direction open, ask him about that first.
        Do not edit, move, or delete the runbook file itself; Lando removes it when he merges.
        Branch off the latest main, make the change, chown the repo, rebuild, and have the
        user confirm it actually works before you commit. Then open a PR with gh pr create.
        If anything in the runbook conflicts with the blaney-pc rules in CLAUDE.md, the rules
        win. Lando reviews and approves all PRs, so make the best call and proceed.
        EOF
        )

        exec sudo claude --settings ${gladeHooks} "$PROMPT"
      '')

      # The walk-away half of blaney-todo: Claude works the runbook with nobody present, opens
      # a PR, then the repo goes back to main and `update-shutdown` pulls, rebuilds and powers
      # off. Run as root via `sudo` from blaney-todo, so the one password prompt happens while
      # insideabush is still at the keyboard and nothing later can hang on another. Same
      # conventions as update-shutdown: no `set -e`, every path must reach poweroff.
      # Results go to the user's ~/.local/state (resolved from SUDO_USER — $HOME under sudo is
      # not reliable) for modules/home-manager/services/rebuild-shutdown-notify.nix to report
      # at the next login.
      (pkgs.writeShellScriptBin "blaney-todo-unattended" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        TARGET="''${1:?runbook path}"
        TITLE="''${2:-$TARGET}"
        REPO="${nixosConfigDir}"
        if [ "$(id -u)" -ne 0 ]; then
          exec sudo "$0" "$@"
        fi

        RUN_USER="''${SUDO_USER:-${userName}}"
        USER_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
        [ -n "$USER_HOME" ] || USER_HOME="${cfg.user.home}"
        STATE="$USER_HOME/.local/state"
        LOG="$STATE/blaney-todo-unattended.log"
        RESULT="$STATE/blaney-todo-result"
        DONE_FILE="$STATE/blaney-todo-done"
        mkdir -p "$STATE"
        rm -f "$RESULT"

        cd "$REPO" || { systemctl poweroff; exit 1; }

        # No questions are possible, so the prompt says so and the permission settings enforce
        # it: auto mode decides each action, and anything that would still prompt is refused
        # rather than waiting forever for an answer nobody will give.
        # No backticks in here: the heredoc is unquoted so $TARGET expands.
        PROMPT=$(cat <<EOF
        Work on the runbook at $TARGET. Read it first with: git show origin/main:$TARGET
        (it may not exist on the branch you are currently on). Then carry out the task it
        describes end to end. This is a blaney-pc session — follow all blaney-pc rules in
        CLAUDE.md: branch prefix blaney/, never push to main, never merge into a branch that
        does not start with blaney/. Do not edit, move, or delete the runbook file itself.

        THIS RUN IS UNATTENDED. The user started it and walked away; nobody will read or answer
        anything until it is over. Never ask a question and never wait for input. Make every
        decision yourself, including how things look and behave — where the runbook leaves
        that open, pick what fits his current setup best (his Windows 7 look on XFCE) and
        record the choice. Verify the change yourself instead of asking him to: branch off the
        latest origin/main, make the change, chown the repo to ${userName}, rebuild, then check it
        with commands, logs, or the headless VM screenshot procedure in docs/test-vms-and-ci.md.
        Then commit, push the blaney/ branch, and open a PR with gh pr create. The PR body must
        include a section "Decisions I made for Blaney" and a section "Needs checking in
        person" listing anything you could not verify. If part of the task physically needs him
        (signing in to an account, typing a password, plugging in hardware), do everything else
        and open the PR as a draft (gh pr create --draft) that says exactly what is left. Do not
        reboot, power off, or log out — a wrapper shuts the machine down after you finish. Leave
        the repo on your blaney/ branch when done. Finish by printing the PR URL. If anything in
        the runbook conflicts with the blaney-pc rules in CLAUDE.md, the rules win. Lando
        reviews and approves all PRs, so make the best call and proceed.
        EOF
        )

        {
          echo "=== blaney-todo: Claude is working on \"$TITLE\" by itself. You can walk away. ==="
          echo "=== Started $(date). When it is done the PC updates and shuts itself off. ==="
        } | tee "$LOG"

        # Keep the machine from sleeping (XFCE idle) or being powered off by the case button
        # mid-task. `timeout` bounds a run that never finishes so the PC still ends up off.
        systemd-inhibit --what=sleep:idle:handle-power-key --who=blaney-todo \
          --why="Claude is doing a task for Blaney" \
          timeout --kill-after=5m 4h \
          claude -p "$PROMPT" --permission-mode auto --permission-prompts none \
          2>&1 | tee -a "$LOG"
        CLAUDE_RC=''${PIPESTATUS[0]}

        BRANCH=$(git branch --show-current 2>/dev/null || true)
        PR_URL=""
        case "$BRANCH" in
          blaney/*) PR_URL=$(gh pr view "$BRANCH" --json url --jq .url 2>/dev/null || true) ;;
        esac

        # One line, "|"-separated: status|title|url (url empty on failure).
        SAFE_TITLE=$(printf '%s' "$TITLE" | tr '|' '/')
        if [ -n "$PR_URL" ]; then
          echo "Done — sent to Lando: $PR_URL" | tee -a "$LOG"
          printf 'ok|%s|%s\n' "$SAFE_TITLE" "$PR_URL" > "$RESULT"
          grep -qxF "$TARGET" "$DONE_FILE" 2>/dev/null || echo "$TARGET" >> "$DONE_FILE"
        else
          echo "Claude did not finish (exit $CLAUDE_RC, branch ''${BRANCH:-none}, no PR found)." | tee -a "$LOG"
          printf 'fail|%s|\n' "$SAFE_TITLE" > "$RESULT"
        fi

        # Back to main so update-shutdown pulls and rebuilds main; the work lives on in the PR.
        # Anything Claude left uncommitted is stashed, tagged with its branch, not thrown away.
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
          git stash push -u -m "blaney-todo:''${BRANCH:-unknown}" >> "$LOG" 2>&1 || true
        fi
        git checkout main >> "$LOG" 2>&1 || true

        chown -R "$RUN_USER:${userGroup}" "$REPO" "$STATE" 2>/dev/null || true

        # update-shutdown powers off on every path; the poweroff after it is the backstop in
        # case it is missing or returns.
        HOME="$USER_HOME" update-shutdown 2>&1 | tee -a "$LOG"
        chown "$RUN_USER:${userGroup}" "$LOG" 2>/dev/null || true
        systemctl poweroff
      '')

      # A notes list for blaney-pc: `add-notes` is a typing box that stays open and adds every
      # line typed into it to ~/notes-list.txt, while `work-notes` (in another terminal)
      # has Claude work through the list by itself, oldest first, waiting for more once it
      # runs dry. All notes from one day stack up on one blaney/notes-<date> branch with one
      # PR, so each rebuild keeps the earlier notes' changes. Line markers: [ ] waiting,
      # [~] being worked on, [x] done, [!] Claude could not finish it.
      (pkgs.writeShellScriptBin "add-notes" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        LIST="${notesList}"
        touch "$LIST"
        waiting() { grep -c '^\[ \]' "$LIST" 2>/dev/null || true; }

        # What these notes are about: his config, or one of his own apps in ~/projects. The
        # pick is put in front of every note as "@<key>:" for work-notes to read.
        KEYS=(setup) LABELS=("Computer setup")
        for d in "$HOME"/projects/*/; do
          k=$(basename "$d")
          case "$k" in
            r62d) l="R6 game" ;;
            hud) l="Glade" ;;
            breifing-room) l="F-117" ;;
            spectrobes-rebuild) l="Spectrobes" ;;
            *) l="$k" ;;
          esac
          KEYS+=("$k") LABELS+=("$l")
        done
        echo "What are these notes about?"
        for i in "''${!KEYS[@]}"; do echo "  $((i + 1))) ''${LABELS[$i]}"; done
        while :; do
          read -rp "Enter a number: " PICK
          [[ "$PICK" =~ ^[0-9]+$ ]] && [ "$PICK" -ge 1 ] && [ "$PICK" -le "''${#KEYS[@]}" ] && break
          echo "That isn't one of the numbers above."
        done
        KEY="''${KEYS[$((PICK - 1))]}" LABEL="''${LABELS[$((PICK - 1))]}"
        printf '\033]2;Notes for: %s\007' "$LABEL"
        clear
        echo "Notes for: $LABEL"
        echo "Type a note and press Enter to add it."
        echo "Type q (or press Ctrl+C) to close. Notes waiting right now: $(waiting)"
        while read -rep "note> " NOTE; do
          NOTE="''${NOTE//$'\n'/ }"
          [ -n "''${NOTE//[[:space:]]/}" ] || continue
          [ "$NOTE" = "q" ] && break
          flock "$LIST" sh -c 'printf "[ ] @%s: %s\n" "$1" "$2" >> "$3"' _ "$KEY" "$NOTE" "$LIST"
          echo "  Added. Notes waiting: $(waiting)"
        done
        echo "Closed. Your notes are kept in $LIST."
      '')

      (pkgs.writeShellScriptBin "work-notes" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        if [ "$(id -u)" -ne 0 ]; then
          exec sudo "$0" "$@"
        fi
        LIST="${notesList}"
        BRANCH="blaney/notes-$(date +%F)"
        RULES="$(cat ${ccnRules})"
        # Its own worktree, so a config chat in the main checkout never has its branch switched
        # (or its uncommitted work swept up) by a note being worked on.
        REPO="${nixosConfigDir}-worktrees/''${BRANCH#blaney/}"
        [ -d "$REPO" ] || (cd "${nixosConfigDir}" && sudo -u ${userName} wt new "$BRANCH") \
          || { echo "Couldn't set up a folder for the notes work — tell Lando."; exit 1; }
        cd "$REPO" || { echo "Can't find the notes work folder at $REPO — tell Lando."; exit 1; }
        touch "$LIST"
        chown ${userName}:${userGroup} "$LIST"

        # Set line N's marker to $2 ([ ], [~], [x] or [!]).
        mark() {
          flock "$LIST" sh -c 'awk -v n="$1" -v m="$2" "NR==n{sub(/^\\[.\\]/, m)}1" "$3" > "$3.tmp" && cat "$3.tmp" > "$3" && rm -f "$3.tmp"' _ "$1" "$2" "$LIST"
        }
        # A note left half-done by a closed window goes back in the queue.
        flock "$LIST" sed -i 's/^\[~\]/[ ]/' "$LIST"

        echo "Claude is working through your notes list by itself. Leave this window open."
        echo "Add notes with the add-notes command in another terminal. Close this window to stop."
        # The Glade panel's bar covers the notes since the list last ran dry: DONE_N of TOTAL,
        # started again at the current total and stepped back up to DONE_N each time
        # (glade-status has no "set" command).
        WAITING_SHOWN="" DONE_N=0 TOTAL=0
        export SUDO_USER="''${SUDO_USER:-${userName}}" # glade-status finds his home through it
        shopt -s lastpipe # the token reader at the end of the claude pipeline sets NOTE_TOK
        kfmt() { awk -v n="$1" 'BEGIN { if (n >= 1000) printf "%.1fk", n / 1000; else print n }'; }
        st() { ${gladeStatus} "$@" >/dev/null 2>&1; }
        while true; do
          N=$(grep -n '^\[ \]' "$LIST" | head -1 | cut -d: -f1)
          if [ -z "$N" ]; then
            if [ -z "$WAITING_SHOWN" ]; then
              echo; echo "All caught up — waiting for new notes..."
              [ "$TOTAL" -gt 0 ] && st done
              WAITING_SHOWN=1 DONE_N=0 TOTAL=0
            fi
            sleep 5
            continue
          fi
          WAITING_SHOWN=""
          NOTE=$(sed -n "''${N}p" "$LIST" | cut -c5-)
          mark "$N" "[~]"
          TOTAL=$((DONE_N + $(grep -c '^\[[ ~]\]' "$LIST")))
          # Each new claude resets the panel as it starts (its SessionStart hook), so the bar
          # is put back a few seconds later, and again every half minute in case.
          bar() {
            st title "Working on your notes ($((DONE_N + 1)) of $TOTAL)"
            st progress "$TOTAL" "$NOTE"
            for _ in $(seq "$DONE_N"); do st step "" "$NOTE"; done
          }
          ( sleep 5; while :; do bar; sleep 30; done ) &
          BAR_PID=$!
          echo
          echo "=== Working on: $NOTE ==="

          PROMPT=$(cat <<EOF
        (Started by work-notes: one note from his notes list.)

        THIS RUN IS UNATTENDED. He asked for his notes to be worked through without being
        asked anything, so this overrides the "ask him first" and "have him confirm" rules:
        never ask a question and never wait for input. Make every decision yourself,
        including how things look and behave, in the spirit of his current setup and saved
        preferences, and verify the change yourself (commands, logs, screenshots).
        The Glade panel's title and progress bar track the whole notes list and are set by
        the wrapper: do not run glade-status title, progress, step or done yourself.

        A note starting "@setup:" is about this config. One starting "@<name>:" is about his
        app in ~/projects/<name>. With no "@", work out which from the note itself.
        If the note is about one of his own apps in ~/projects (for example his R6 game,
        r62d), make the change there instead, following that project's own CLAUDE.md and
        docs/hosts/blaney-vibe-projects.md: commit to its main and push it. Never bump the
        app's pin in this config for it: this computer builds his packaged apps from
        ~/projects, so the rebuild below installs the change by itself. A pin only moves for
        a release he asks for, in its own PR, never in this notes branch.

        For a config change: work only in this worktree, $REPO, which is on the branch
        $BRANCH (never touch the main checkout at ${nixosConfigDir}; another chat uses it).
        Bring $BRANCH up to date with origin/main first. Earlier notes from today are already
        on it; keep their changes. Make the change, chown the worktree to ${userName},
        rebuild --take (this worktree must own the live system), check it works, commit, and push $BRANCH. If $BRANCH
        has no open PR yet, open one with gh pr create; otherwise add a line for this note to
        the PR body (gh pr edit). The PR body keeps a list of the notes done, plus sections
        "Decisions I made for Blaney" and "Needs checking in person". If the note needs him
        physically (a password, hardware), do what you can and list the rest there. Do not
        reboot, power off or log out, and leave the repo on $BRANCH when done.

        His note:
        $NOTE
        EOF
          )
          # Shown live, like a chat he watches: Claude's words, and one line per thing it does
          # with the note's running token count (each message's new input + cache writes +
          # output; cache reads left out, as they cost a tenth). A message's content blocks
          # arrive as separate events with the same usage, hence the seen-by-id check. The
          # final "@@TOKENS n" line is caught below for the per-note and per-day totals.
          NOTE_TOK=0
          timeout --kill-after=5m 2h \
            claude -p "$PROMPT" --settings ${gladeHooks} --append-system-prompt "$RULES" \
              --permission-mode auto --permission-prompts none \
              --output-format stream-json --verbose \
            | ${pkgs.jq}/bin/jq -nr --unbuffered '
                def k: if . >= 1000 then "\((. / 100 | floor) / 10)k" else tostring end;
                foreach (inputs | select(.type == "assistant" or .type == "result")) as $e
                  ({seen: {}, total: 0, out: []};
                   if $e.type == "result" then .out = ["@@TOKENS \(.total)"]
                   else ($e.message.usage // {}) as $u
                     | (if .seen[$e.message.id] then 0
                        else ($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0)
                             + ($u.output_tokens // 0) end) as $add
                     | .seen[$e.message.id] = true | .total += $add | .total as $t
                     | .out = [$e.message.content[]
                         | if .type == "text" then "\n" + .text + "\n"
                           elif .type == "tool_use" then
                             "  > " + .name + ": " + ((.input.description // .input.command
                               // .input.file_path // .input.pattern // "") | tostring
                               | gsub("\n"; " ") | .[0:120]) + "   [\($t | k) tokens]"
                           else empty end]
                   end;
                   .out[])' 2>/dev/null \
            | while IFS= read -r LINE; do
                case "$LINE" in
                  "@@TOKENS "*) NOTE_TOK=''${LINE#@@TOKENS } ;;
                  *) printf '%s\n' "$LINE" ;;
                esac
              done
          RC=''${PIPESTATUS[0]}
          kill "$BAR_PID" 2>/dev/null
          # Today's total, kept across windows in "<date> <tokens>".
          TOKFILE="${cfg.user.home}/.local/state/work-notes-tokens"
          read -r TDAY TTOK < "$TOKFILE" 2>/dev/null || true
          [ "''${TDAY:-}" = "$(date +%F)" ] || TTOK=0
          TTOK=$((''${TTOK:-0} + NOTE_TOK))
          echo "$(date +%F) $TTOK" > "$TOKFILE"
          chown ${userName}:${userGroup} "$TOKFILE"
          TOKS="(this note: $(kfmt "$NOTE_TOK") tokens, today: $(kfmt "$TTOK"))"
          chown -R ${userName}:${userGroup} "$REPO"
          if [ "$RC" -eq 0 ]; then
            mark "$N" "[x]"
            echo "=== Done: $NOTE $TOKS ==="
          else
            mark "$N" "[!]"
            echo "=== Claude couldn't finish this one (marked [!] in your list): $NOTE $TOKS ==="
          fi
          DONE_N=$((DONE_N + 1))
        done
      '')

      # The "Notes" tree squid on his Glade (hosts/blaney-pc/home.nix): the notes window,
      # plus the work window unless one is already running (two would fight over the list).
      (pkgs.writeShellScriptBin "notes-windows" ''
        #!${pkgs.stdenv.shell}
        setsid kitty --title "Notes" add-notes >/dev/null 2>&1 &
        if ! pgrep -f "bin/work-notes" >/dev/null; then
          setsid kitty --title "Claude working on notes" work-notes >/dev/null 2>&1 &
        fi
      '')

      (pkgs.writeShellScriptBin "blaney-help" ''
        #!${pkgs.stdenv.shell}
        cat <<'EOF'
        Blaney's commands — type any of these in a terminal.

        EVERYDAY
          rebuild           Apply your config changes to the system
          rebuild-shutdown  Rebuild the system, then shut down (run and walk away)
          update-shutdown   Get the latest updates, then shut down (the weekly update, on demand)
          update            Download the latest config from GitHub
          branch-switch     Pick a branch by number, switch to it, and rebuild
          smart-rebuild     Safely get back to the latest main and rebuild
          rb                Rebuild, then reboot
          c                 Clear the screen

        TALK TO CLAUDE — start here
          vibe                   Everything you do with Claude: change or fix
                                 something on your computer, start a new app or
                                 carry on with one, make a game, or take apart
                                 a program or game

        MORE CLAUDE HELPERS
          blaney-todo            See tasks Lando left you and have Claude do one
                                 (with you, or on its own and then shut down)
          claude-rebuild-failed  Ask Claude to fix a failed rebuild and make a PR
          add-notes              Type notes into your list of things to change
          work-notes             Have Claude work through that list by itself
                                 (run it in a second terminal)

        GAMES
          batman join    The Batman: play Robin in Lando's game (homelab VPN on)
          batman coop    The Batman: two players on this PC (also in the start menu)

        OTHER
          rebuild-test   Try a rebuild temporarily (undone on reboot)
          ipr            Open the input-remapper (button remap) app
          whats-new      Show Lando's release notes again
          blaney-help    Show this list again
          sync           Old name for "update" — still works, but use update
          ccn            Old way to talk to Claude — now part of vibe
        EOF
      '')
    ];

    # The config chat is one of `vibe`'s menu entries (modules/nixos/programs/vibe-projects.nix).
    customConfig.programs.vibeProjects.configChat = "${configChat}";
  };
}
