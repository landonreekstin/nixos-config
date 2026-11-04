# ~/nixos-config/modules/nixos/common/lando-commands.nix
{ config, pkgs, lib, ... }:

# lando's counterpart to `blaney-todo` (see ./blaney-commands.nix): a numbered menu of the
# runbooks in docs/runbooks/lando/ that opens Claude on the chosen one. Gated to the lando
# user, so this module is a no-op on every other host. See docs/runbooks/lando/README.md.
let
  cfg = config.customConfig;
  nixosConfigDir = "${cfg.user.home}/nixos-config"; # Path to the cloned Git repository
in
{
  config = lib.mkIf (cfg.user.name == "lando") {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "landon-todo" ''
        #!${pkgs.stdenv.shell}
        set -uo pipefail
        REPO="${nixosConfigDir}"
        if [ ! -d "$REPO/.git" ]; then
          echo "Can't find the config at $REPO."
          exit 1
        fi
        cd "$REPO" || exit 1

        RUNBOOK_DIR="docs/runbooks/lando"

        echo "Checking for new tasks..."
        git fetch --quiet origin main 2>/dev/null \
          || echo "(couldn't reach GitHub, showing the tasks already on this machine)"

        # Pending tasks are the markdown files on main. The README in that folder is the
        # how-to for writing them, not a task.
        mapfile -t FILES < <(git ls-tree --name-only origin/main "$RUNBOOK_DIR/" 2>/dev/null \
          | grep '\.md$' | grep -v '/README\.md$')

        if [ "''${#FILES[@]}" -eq 0 ]; then
          echo
          echo "No tasks right now."
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

        echo
        echo "What do you want Claude to work on?"
        for i in "''${!TITLES[@]}"; do
          printf "  %d) %s\n" $((i + 1)) "''${TITLES[$i]}"
        done
        echo

        read -rp "Enter a number (or q to cancel): " CHOICE
        [ "$CHOICE" = q ] && { echo "Cancelled, nothing started."; exit 0; }
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] \
             || [ "$CHOICE" -gt "''${#FILES[@]}" ]; then
          echo "That wasn't a valid choice. Nothing started."
          exit 1
        fi
        TARGET="''${FILES[$((CHOICE - 1))]}"
        TITLE="''${TITLES[$((CHOICE - 1))]}"

        echo
        echo "Starting Claude on: $TITLE"
        echo

        # No backticks in here: the heredoc is unquoted so $TARGET expands.
        PROMPT=$(cat <<EOF
        Work on the runbook at $TARGET. Read it first with: git show origin/main:$TARGET
        (it may not exist on the branch you are currently on). Then carry out the task it
        describes, following CLAUDE.md as usual, including the parallel-session check and
        the choose-the-right-host check: if the runbook belongs on a different host than
        this one, say so before starting. This is lando's own session, so ask him about any
        decision the runbook leaves open. When the task is finished, delete the runbook file
        in the same change; deleting it is what removes the task from the landon-todo menu.
        EOF
        )

        exec sudo claude "$PROMPT"
      '')
    ];
  };
}
