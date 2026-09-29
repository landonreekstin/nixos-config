# ~/nixos-config/modules/nixos/common/commands.nix
{ config, pkgs, lib, ... }:

let
  # Retrieve values from custom options. These must be set in the host's specific configuration.
  cfg = config.customConfig;
  nixosConfigDir = "${cfg.user.home}/nixos-config"; # Path to the cloned Git repository
  hostName = cfg.system.hostName;
  userName = cfg.user.name;
  userGroup = config.users.users.${userName}.group;

  # --- Parallel worktrees ---------------------------------------------------
  # Several sessions can edit the config at once, each in its own git worktree, but the
  # machine can only have ONE configuration *activated*. These paths hold the record of
  # which worktree that is. See docs/parallel-sessions.md.
  worktreeRoot = "${cfg.user.home}/nixos-config-worktrees";
  wtStateDir = "/var/lib/nixos-config";
  wtOwnerFile = "${wtStateDir}/active-worktree";
  wtLockFile = "${wtStateDir}/rebuild.lock";

  # Shell helpers shared by `rebuild`, `rebuild-test`, `flake-update`, `upgrade` and
  # `wt`. Interpolated into each script rather than sourced, so every command stays a
  # self-contained store path with no runtime dependency on the others.
  worktreeLib = ''
    MAIN_CONFIG="${nixosConfigDir}"
    WT_ROOT="${worktreeRoot}"
    WT_STATE_DIR="${wtStateDir}"
    WT_OWNER_FILE="${wtOwnerFile}"
    WT_LOCK="${wtLockFile}"

    # Claude Code runs as root inside ${userName}'s checkout, and git refuses to read a
    # repo owned by someone else ("dubious ownership"). Without this override every
    # resolution below would fail and fall back to the main checkout — silently
    # rebuilding a tree other than the one you are standing in.
    wt_git() { git -c safe.directory='*' "$@"; }

    # The flake directory for the CURRENT directory: the enclosing worktree when it
    # belongs to the config repo, otherwise the main checkout. That fallback preserves
    # the pre-worktree behaviour of `rebuild` run from anywhere else on the system.
    wt_flake_dir() {
      local top common main_common
      top=$(wt_git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || { echo "$MAIN_CONFIG"; return; }
      [ -f "$top/flake.nix" ] || { echo "$MAIN_CONFIG"; return; }
      common=$(wt_git -C "$top" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "$MAIN_CONFIG"; return; }
      main_common=$(wt_git -C "$MAIN_CONFIG" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "$MAIN_CONFIG"; return; }
      if [ "$common" = "$main_common" ]; then echo "$top"; else echo "$MAIN_CONFIG"; fi
    }

    wt_branch() { wt_git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?"; }
    wt_head()   { wt_git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "?"; }
    wt_dirty()  { wt_git -C "$1" status --porcelain 2>/dev/null | grep -c . || true; }

    wt_owner_field() { [ -r "$WT_OWNER_FILE" ] || return 0; sed -n "s/^$1=//p" "$WT_OWNER_FILE" | head -n1; }

    # Which worktree's code is currently activated. No record (fresh state dir) means
    # nobody has claimed it, and the main checkout is the default owner.
    wt_owner_path() {
      local p; p=$(wt_owner_field path)
      if [ -n "$p" ] && [ -d "$p" ]; then echo "$p"; else echo "$MAIN_CONFIG"; fi
    }

    # The record is only trustworthy while the system it described is still the live one.
    # The weekly auto-update unit and a hand-run nixos-rebuild both move
    # /run/current-system without going through `rebuild`, which makes it a lie.
    wt_owner_stale() {
      local rec; rec=$(wt_owner_field toplevel)
      [ -n "$rec" ] || return 1
      [ "$rec" != "$(readlink -f /run/current-system)" ]
    }

    wt_claim() {
      local dir="$1"
      sudo install -d -m 0755 "$WT_STATE_DIR" 2>/dev/null || true
      printf 'path=%s\nbranch=%s\nhead=%s\ntoplevel=%s\nwhen=%s\nby=%s\n' \
        "$dir" "$(wt_branch "$dir")" "$(wt_head "$dir")" \
        "$(readlink -f /run/current-system)" "$(date +%s)" "''${SUDO_USER:-$(id -un)}" \
        | sudo tee "$WT_OWNER_FILE" >/dev/null
    }

    # A hard gate, not a warning. Activating from a non-owning worktree means everything
    # you "verify" afterwards is the OTHER worktree's code, and CLAUDE.md makes
    # verify-before-commit non-negotiable — a warning would not be enough.
    wt_require_owner() {
      local dir="$1" take="$2" owner when
      owner=$(wt_owner_path)
      if [ "$dir" = "$owner" ]; then
        if wt_owner_stale; then
          echo "Note: the live system was last changed outside 'rebuild' (auto-update, or"
          echo "      a manual nixos-rebuild). Re-activating from this worktree."
        fi
        return 0
      fi
      if [ "$take" = "1" ]; then
        echo "--> taking the live system from $(wt_branch "$owner")  ($owner)"
        return 0
      fi
      when=$(wt_owner_field when)
      [ -n "$when" ] && when=$(date -d "@$when" '+%H:%M' 2>/dev/null || echo "")
      {
        echo ""
        echo "REFUSED: ${hostName}'s live system is owned by:"
        echo "    $owner"
        echo "    branch $(wt_branch "$owner")''${when:+  (activated $when)}"
        echo ""
        echo "  You are in:"
        echo "    $dir"
        echo "    branch $(wt_branch "$dir")"
        echo ""
        echo "  Verification here would be testing THAT branch's code."
        echo "  Run 'rebuild --take' to move ownership to this worktree."
        echo ""
      } >&2
      return 1
    }

    # nix reads the flake through libgit2, which refuses to open a repo owned by another
    # user. The check passes when the *sudo-invoking* user owns it — which is the case when
    # ${userName} runs these commands normally. A session that is ALREADY root (Claude runs
    # as `sudo claude`) nests a second sudo, and that resets SUDO_UID to 0, so the identical
    # command fails with an opaque "repository path ... is not owned by current user
    # (libgit2 error code = 7)". Pass the flake directory's real owner so both paths behave
    # the same.
    #
    # An exact `safe.directory` entry also satisfies libgit2 — that is what hand-written
    # entries in root's ~/.gitconfig were silently doing for the main checkout — but the
    # trailing-glob form that plain git accepts is IGNORED by nix's libgit2, so it cannot
    # cover a directory of worktrees. Hence this rather than a config entry.
    wt_sudo_rebuild() {
      local dir="$1"; shift
      sudo env SUDO_UID="$(stat -c %u "$dir")" SUDO_GID="$(stat -c %g "$dir")" \
        nixos-rebuild "$@"
    }

    # Serialise activations: two nixos-rebuild switches at once genuinely race, and
    # parallel sessions make that reachable. A lock that cannot be taken must never stop
    # the machine from being rebuilt, so every failure here is deliberately non-fatal.
    wt_lock() {
      if [ ! -e "$WT_LOCK" ]; then
        sudo install -d -m 0755 "$WT_STATE_DIR" 2>/dev/null || true
        sudo install -m 0664 -o root -g ${userGroup} /dev/null "$WT_LOCK" 2>/dev/null || true
      fi
      exec 9>"$WT_LOCK" 2>/dev/null || return 0
      if ! flock -n 9 2>/dev/null; then
        echo "Another rebuild is running on this machine — waiting for it to finish..."
        flock 9 2>/dev/null || true
      fi
    }
  '';

  post-install-script = pkgs.writeShellScriptBin "post-install" ''
    #!/usr/bin/env bash
    set -e

    # =============================================================================
    # NixOS Post-Install Setup Script (v5 - HTTPS Clone Method, Final)
    # =============================================================================

    # Change to the home directory to ensure a safe execution environment.
    cd ~

    # --- Configuration ---
    # We use the public HTTPS URL for the initial clone, which requires no auth.
    GIT_HTTPS_URL="https://github.com/landonreekstin/nixos-config.git"
    # We define the SSH URL for when we need to push later.
    GIT_SSH_URL="git@github.com:landonreekstin/nixos-config.git"
    CONFIG_DIR="$HOME/nixos-config"

    # --- Pre-flight Checks ---
    if [[ "$EUID" -eq 0 ]]; then
      echo "❌ This script should be run as your normal user, not as root."
      exit 1
    fi

    # --- Step 1: Clone the Repository via HTTPS ---
    echo "--- Cloning from $GIT_HTTPS_URL ---"
    
    if [[ -d "$CONFIG_DIR" ]]; then
        echo "ℹ️ Found an existing '$CONFIG_DIR'. Removing it for a clean clone."
        rm -rf "$CONFIG_DIR"
    fi

    git clone "$GIT_HTTPS_URL" "$CONFIG_DIR"
    cd "$CONFIG_DIR" # Now we cd into the new repository for all subsequent commands.
    echo "✅ Repository cloned successfully."
    echo "-----------------------------------------"

    # --- Step 2: Re-generate Hardware Configuration ---
    echo "--- Generating final hardware configuration on the new system ---"
    
    DEST_HARDWARE_CONFIG="$CONFIG_DIR/hosts/$(hostname)/hardware-configuration.nix"
    
    sudo nixos-generate-config --no-filesystems
    sudo mv /etc/nixos/hardware-configuration.nix "$DEST_HARDWARE_CONFIG"
    sudo chown "$(whoami):$(id -gn)" "$DEST_HARDWARE_CONFIG"
    sudo rm -rf /etc/nixos
    echo "✅ Hardware configuration generated and moved successfully."
    echo "----------------------------------------------------------"

    # --- Step 3: SSH Key Setup ---
    echo ""
    echo "--- GitHub SSH Key Setup ---"
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

    if [ -f "$SSH_KEY_PATH" ]; then
      echo "ℹ️ SSH key already exists. Skipping generation."
    else
      echo "Generating a new SSH key..."
      ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SSH_KEY_PATH" -N ""
      echo "✅ New SSH key generated."
    fi

    echo ""
    echo "🔴 ACTION REQUIRED: Please add the following public SSH key to your GitHub account."
    echo "   You can do this at: https://github.com/settings/keys"
    echo ""
    echo "------------------------- COPY THE KEY BELOW -------------------------"
    cat "''${SSH_KEY_PATH}.pub"
    echo "--------------------------------------------------------------------"
    echo ""
    read -p "Press [Enter] to continue once you have added the key to GitHub..."
    
    # --- Step 4: Finalize Git Configuration and Push ---
    echo ""
    echo "--- Finalizing Git Configuration for Pushing ---"
    
    echo "Testing SSH connection to GitHub..."
    if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
      echo "✅ SSH connection to GitHub successful."
    else
      echo "❌ SSH connection to GitHub failed. Please check the key and try again."
      exit 1
    fi
    
    echo "Switching Git remote from HTTPS to SSH for push access..."
    git remote set-url origin "$GIT_SSH_URL"
    echo "✅ Remote URL updated."

    git add "$DEST_HARDWARE_CONFIG"
    git commit -m "feat(hosts): Add hardware configuration for $(hostname)"
    
    echo "Pushing changes to the repository..."
    git push

    echo ""
    echo "🎉 All done! Your new machine is fully configured and your repository is up-to-date."
  '';

in
{

  # Add the custom command scripts to the system's PATH
  # ~/nixos-config/modules/nixos/common/commands.nix

  # Add the custom command scripts to the system's PATH
  environment.systemPackages = (with pkgs; [
    # --- Unconditional Commands ---
    git # Ensure git is available for the 'update' command

    post-install-script

    # Manage the parallel worktrees of the config repo. One checkout per task means
    # concurrent sessions stop sharing a working tree (and stop committing each other's
    # half-finished files); `rebuild` decides which of them owns the live system.
    # Full workflow: docs/parallel-sessions.md
    (writeShellScriptBin "wt" ''
      #!${stdenv.shell}
      set -uo pipefail

      ${worktreeLib}

      usage() {
        cat <<'USAGE'
      Usage: wt [command]

        wt                       list every worktree of the config repo
        wt list                  same as above
        wt new <branch>          create a worktree for <branch>
             [--from <ref>]      base a new branch on <ref>       (default origin/main)
             [--name <dir>]      directory name under the worktree root
        wt rm <name> [--force]   remove a worktree (refuses if it has uncommitted work)
        wt status                show which worktree owns the live system

      Only one worktree can be activated on this machine at a time: 'rebuild' builds the
      worktree you are standing in and refuses if another one owns the live system.
      USAGE
      }

      # Claude Code runs as root; anything it creates in the user's tree has to go back
      # to the user or the next non-root git command in that worktree fails.
      wt_own_files() {
        chown -R ${userName}:${userGroup} "$1" 2>/dev/null \
          || sudo chown -R ${userName}:${userGroup} "$1" 2>/dev/null || true
      }

      wt_paths() {
        wt_git -C "$MAIN_CONFIG" worktree list --porcelain 2>/dev/null \
          | sed -n 's/^worktree //p'
      }

      CMD="''${1:-list}"
      [ $# -gt 0 ] && shift

      case "$CMD" in
        -h|--help|help) usage; exit 0 ;;

        list)
          OWNER=$(wt_owner_path)
          printf '%-2s %-52s %-38s %s\n' "" "WORKTREE" "BRANCH" "STATE"
          while read -r d; do
            [ -n "$d" ] || continue
            mark=" "; [ "$d" = "$OWNER" ] && mark="*"
            n=$(wt_dirty "$d"); st="clean"
            [ "''${n:-0}" -gt 0 ] && st="$n uncommitted"
            printf '%-2s %-52s %-38s %s\n' "$mark" "$d" "$(wt_branch "$d")" "$st"
          done < <(wt_paths)
          echo
          echo "* owns the live system — the only worktree where 'rebuild' works without --take"
          wt_owner_stale && echo "  (record is stale: the system was last changed outside 'rebuild')"
          exit 0 ;;

        status)
          OWNER=$(wt_owner_path)
          echo "Live system owner: $OWNER"
          echo "           branch: $(wt_branch "$OWNER")"
          if [ -r "$WT_OWNER_FILE" ]; then
            W=$(wt_owner_field when)
            [ -n "$W" ] && echo "        activated: $(date -d "@$W" 2>/dev/null || echo "$W") by $(wt_owner_field by)"
            echo "        at commit: $(wt_owner_field head)"
          else
            echo "                   (no record yet — the main checkout is the default owner)"
          fi
          if wt_owner_stale; then
            echo
            echo "WARNING: /run/current-system no longer matches that record. Something rebuilt"
            echo "this machine outside 'rebuild' (the weekly auto-update, or a manual"
            echo "nixos-rebuild), so treat the owner above as unverified."
          fi
          exit 0 ;;

        new)
          [ $# -ge 1 ] || { echo "wt new: need a branch name" >&2; exit 1; }
          BRANCH="$1"; shift
          BASE="origin/main"; NAME=""
          while [ $# -gt 0 ]; do
            case "$1" in
              --from) [ $# -ge 2 ] || { echo "wt new: --from needs a ref" >&2; exit 1; }; BASE="$2"; shift 2 ;;
              --name) [ $# -ge 2 ] || { echo "wt new: --name needs a value" >&2; exit 1; }; NAME="$2"; shift 2 ;;
              *) echo "wt new: unknown option '$1'" >&2; exit 1 ;;
            esac
          done
          [ -n "$NAME" ] || NAME="''${BRANCH##*/}"
          DIR="$WT_ROOT/$NAME"
          if [ -e "$DIR" ]; then
            echo "wt: $DIR already exists — pick another --name, or 'wt rm $NAME' first" >&2
            exit 1
          fi
          mkdir -p "$WT_ROOT" || { sudo mkdir -p "$WT_ROOT" && wt_own_files "$WT_ROOT"; }
          wt_git -C "$MAIN_CONFIG" fetch origin --quiet \
            || echo "warning: fetch failed — falling back to the refs already on disk"
          if wt_git -C "$MAIN_CONFIG" show-ref --verify --quiet "refs/heads/$BRANCH"; then
            wt_git -C "$MAIN_CONFIG" worktree add "$DIR" "$BRANCH" || exit 1
          elif wt_git -C "$MAIN_CONFIG" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
            wt_git -C "$MAIN_CONFIG" worktree add --track -b "$BRANCH" "$DIR" "origin/$BRANCH" || exit 1
          else
            wt_git -C "$MAIN_CONFIG" worktree add -b "$BRANCH" "$DIR" "$BASE" || exit 1
          fi
          wt_own_files "$DIR"
          echo
          echo "Worktree ready:  $DIR"
          echo "Branch:          $BRANCH"
          echo
          echo "  cd $DIR"
          echo
          echo "The live system still belongs to $(wt_branch "$(wt_owner_path)") — run"
          echo "'rebuild --take' from the new worktree when it is that branch's turn to be tested."
          exit 0 ;;

        rm)
          [ $# -ge 1 ] || { echo "wt rm: need a worktree name" >&2; exit 1; }
          TARGET="$1"; shift
          FORCE=0
          for a in "$@"; do
            case "$a" in
              -f|--force) FORCE=1 ;;
              *) echo "wt rm: unknown option '$a'" >&2; exit 1 ;;
            esac
          done
          DIR="$WT_ROOT/$TARGET"
          if [ ! -d "$DIR" ]; then
            DIR=$(wt_paths | grep -E "/$TARGET\$" | head -n1)
          fi
          if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
            echo "wt rm: no worktree called '$TARGET' (try 'wt list')" >&2; exit 1
          fi
          if [ "$DIR" = "$MAIN_CONFIG" ]; then
            echo "wt rm: refusing to remove the main checkout" >&2; exit 1
          fi
          if [ "$DIR" = "$(wt_owner_path)" ] && [ "$FORCE" -eq 0 ]; then
            echo "wt rm: $DIR owns the live system — the running config would have no source tree." >&2
            echo "       Rebuild from another worktree first ('rebuild --take'), or pass --force." >&2
            exit 1
          fi
          if [ "$FORCE" -eq 1 ]; then
            wt_git -C "$MAIN_CONFIG" worktree remove --force "$DIR" || exit 1
          else
            wt_git -C "$MAIN_CONFIG" worktree remove "$DIR" || {
              echo "wt rm: worktree has uncommitted work — commit it, or pass --force to discard." >&2
              exit 1
            }
          fi
          wt_git -C "$MAIN_CONFIG" worktree prune
          echo "Removed $DIR"
          exit 0 ;;

        *) echo "wt: unknown command '$CMD'" >&2; echo >&2; usage >&2; exit 1 ;;
      esac
    '')

    (writeShellScriptBin "update" ''
      #!${stdenv.shell}
      set -e # Exit immediately if a command exits with a non-zero status

      echo "--- Updating NixOS Configuration ---"
      NIXOS_CONFIG_DIR="${nixosConfigDir}" # This value is injected by Nix at build time

      if [ ! -d "$NIXOS_CONFIG_DIR" ]; then
        echo "Error: Configuration directory '$NIXOS_CONFIG_DIR' does not exist."
        echo "Please ensure the NixOS configuration repository is cloned to that location."
        exit 1
      fi

      cd "$NIXOS_CONFIG_DIR"
      echo "Changed directory to: $(pwd)"

      echo "Fetching latest changes from remote repository..."
      git fetch

      ${lib.optionalString cfg.system.betaTesterHost ''
        # Beta host: track latest open update/* branch if one exists
        BETA_BRANCH=$(git branch -r --list 'origin/update/*' \
          | sort -V | tail -1 | sed 's|.*origin/||' | tr -d ' ')
        if [ -n "$BETA_BRANCH" ]; then
          CURRENT=$(git branch --show-current)
          if [ "$CURRENT" != "$BETA_BRANCH" ]; then
            echo "--- Beta host: switching to $BETA_BRANCH ---"
            git checkout -B "$BETA_BRANCH" "origin/$BETA_BRANCH"
          else
            git pull origin "$BETA_BRANCH" --rebase
          fi
          echo "Update complete (beta branch: $BETA_BRANCH)."
          exit 0
        fi
        echo "--- No update branch found, falling back to main ---"
      ''}

      echo "Attempting to pull latest changes..."
      # Try a simple pull first
      if ! git pull; then
        echo "Git pull failed. This might be due to local changes."
        echo "Attempting to stash local changes and pull again..."
        if git stash push -m "Autostash before update command"; then
          if git pull; then
            echo "Pull successful after stashing."
            echo "Stashed changes can be restored by running 'git stash pop' in $NIXOS_CONFIG_DIR"
          else
            echo "Error: Git pull still failed after stashing."
            echo "You may need to manually resolve conflicts or commit/stash your changes in $NIXOS_CONFIG_DIR"
            # Attempt to restore the stash if the pull failed after stashing
            git stash pop || echo "Warning: Failed to pop automatically stashed changes. Check 'git stash list'."
            exit 1
          fi
        else
          echo "Error: Git stash failed. Please resolve local changes in $NIXOS_CONFIG_DIR manually and try updating again."
          exit 1
        fi
      fi
      echo "Update complete."
    '')

    # Builds the worktree you are standing in, not a fixed path — see
    # docs/parallel-sessions.md. Only the worktree that owns the live system may
    # activate; `--take` moves that ownership here.
    (writeShellScriptBin "rebuild" ''
      #!${stdenv.shell}
      set -e

      TAKE=0
      for arg in "$@"; do
        case "$arg" in
          --take) TAKE=1 ;;
          -h|--help)
            echo "Usage: rebuild [--take]"
            echo "  Rebuilds the config worktree containing the current directory."
            echo "  --take   activate from here even if another worktree owns the system"
            exit 0 ;;
          *) echo "rebuild: unknown option '$arg' (see 'rebuild --help')" >&2; exit 1 ;;
        esac
      done

      ${worktreeLib}

      FLAKE_DIR=$(wt_flake_dir)
      wt_require_owner "$FLAKE_DIR" "$TAKE"
      FLAKE_PATH="$FLAKE_DIR#${hostName}"

      echo "--- Rebuilding NixOS Configuration ---"
      echo "Rebuilding NixOS configuration for host: '${hostName}'"
      echo "Using flake: $FLAKE_PATH"
      echo "Branch: $(wt_branch "$FLAKE_DIR")"

      wt_lock
      wt_sudo_rebuild "$FLAKE_DIR" switch --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
      wt_claim "$FLAKE_DIR"
      echo "Rebuild complete."

      # Push new system closure to NAS binary cache if reachable (skips on the NAS itself).
      # Post-migration the NAS lives at 192.168.100.76 on the server subnet; SSH to it is
      # reachable from gaming-pc via the wg-nas tunnel and from server-subnet hosts directly.
      # LAN hosts without a route to it fail the ping gate below and skip the push (harmless).
      NAS_IP="192.168.100.76"
      if [ "${hostName}" != "optiplex-nas" ] && ping -c 1 -W 2 "$NAS_IP" > /dev/null 2>&1; then
        echo "--- Pushing build to NAS binary cache ---"
        STORE_PATHS=$(nix path-info --recursive /run/current-system)
        PATH_COUNT=$(echo "$STORE_PATHS" | wc -l | tr -d ' ')
        echo "Pushing $PATH_COUNT store paths to ssh://lando@$NAS_IP..."
        set +e
        # shellcheck disable=SC2086 - word splitting is intentional for path list
        NIX_SSHOPTS="-i /home/lando/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new" \
          nix copy --to "ssh://lando@$NAS_IP" $STORE_PATHS
        PUSH_EXIT=$?
        set -e
        if [ "$PUSH_EXIT" -eq 0 ]; then
          echo "✓ Cache push complete."
        else
          echo "✗ Cache push failed (exit $PUSH_EXIT) — rebuild was still successful."
        fi
      fi
    '')

    # Run a rebuild, then power off when it finishes — designed to be started and walked
    # away from. On failure it still powers off (the system is unchanged — a failed switch
    # keeps the old, working generation), but drops a marker so the user is notified on next
    # login (see modules/home-manager/services/rebuild-shutdown-notify.nix). NOTE: no `set -e`
    # here (must reach poweroff even on failure), and `systemctl poweroff` is used WITHOUT sudo
    # so a long rebuild can't leave it hung on a password prompt with nobody present.
    (writeShellScriptBin "rebuild-shutdown" ''
      #!${stdenv.shell}
      echo "=== rebuild-shutdown: updating, then powering off. You can walk away. ==="
      MARKER="$HOME/.local/state/rebuild-shutdown-failed"
      mkdir -p "$HOME/.local/state"
      rm -f "$MARKER"
      if rebuild; then
        echo "Rebuild complete — powering off."
      else
        echo "Rebuild FAILED — recording it; you'll be told on next login. Powering off anyway."
        date > "$MARKER" 2>/dev/null || true
      fi
      systemctl poweroff
    '')

    # The on-demand equivalent of the weekly auto-update (modules/nixos/common/auto-update.nix):
    # pull the config from GitHub, rebuild, then power off. Distinct from `rebuild-shutdown`
    # above, which rebuilds the flake *as it already is on disk* and never fetches. Same
    # conventions as that command and for the same reasons: no `set -e` (poweroff must be
    # reached even on failure — a failed switch leaves the old, working generation), poweroff
    # without sudo (a long run must not hang on a password prompt), and the shared failure
    # marker so modules/home-manager/services/rebuild-shutdown-notify.nix reports it at the
    # next login.
    (writeShellScriptBin "update-shutdown" ''
      #!${stdenv.shell}
      echo "=== update-shutdown: downloading updates, rebuilding, then powering off. You can walk away. ==="
      MARKER="$HOME/.local/state/rebuild-shutdown-failed"
      mkdir -p "$HOME/.local/state"
      rm -f "$MARKER"
      if ! update; then
        echo "Download FAILED — nothing was changed; recording it. Powering off."
        date > "$MARKER" 2>/dev/null || true
      elif rebuild; then
        echo "Update complete — powering off."
      else
        echo "Rebuild FAILED — recording it; you'll be told on next login. Powering off anyway."
        date > "$MARKER" 2>/dev/null || true
      fi
      systemctl poweroff
    '')

    # `test` activates the same as `switch` (it only skips the boot entry), so it takes
    # the same ownership gate and the same lock as `rebuild`.
    (writeShellScriptBin "rebuild-test" ''
      #!${stdenv.shell}
      set -e

      TAKE=0
      for arg in "$@"; do
        case "$arg" in
          --take) TAKE=1 ;;
          -h|--help)
            echo "Usage: rebuild-test [--take]"
            echo "  Activates the current worktree's config without a boot entry."
            exit 0 ;;
          *) echo "rebuild-test: unknown option '$arg'" >&2; exit 1 ;;
        esac
      done

      ${worktreeLib}

      FLAKE_DIR=$(wt_flake_dir)
      wt_require_owner "$FLAKE_DIR" "$TAKE"
      FLAKE_PATH="$FLAKE_DIR#${hostName}"

      echo "--- Testing NixOS Configuration (no boot entry) ---"
      echo "Activating config for host: '${hostName}' (reverts on reboot)"
      echo "Using flake: $FLAKE_PATH"
      echo "Branch: $(wt_branch "$FLAKE_DIR")"

      wt_lock
      wt_sudo_rebuild "$FLAKE_DIR" test --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
      wt_claim "$FLAKE_DIR"
      echo "Test activation complete. Reboot to revert."
    '')

    (writeShellScriptBin "testvm" ''
      #!${stdenv.shell}
      set -euo pipefail
      # Build and launch a throwaway QEMU test VM (see hosts/vm-common.nix). Needs KVM +
      # a display, so run it at a desktop host (gaming-pc). Disks live in a cache dir so
      # they persist between runs and don't clutter the cwd.
      VMDIR="${cfg.user.home}/.cache/nixos-testvms"
      CONFIG="${nixosConfigDir}"

      usage() {
        echo "Usage: testvm <sandbox|blaney> [--clean]"
        echo "  Builds and launches a throwaway test VM (login: password 'vm')."
        echo "  --clean, -c   discard the VM's disk first for a fresh boot"
        exit 1
      }

      [ $# -ge 1 ] || usage
      NAME="$1"; shift
      CLEAN=0
      for arg in "$@"; do
        case "$arg" in
          --clean|-c) CLEAN=1 ;;
          *) echo "Unknown option: $arg"; usage ;;
        esac
      done

      case "$NAME" in
        sandbox|vm-sandbox) HOST="vm-sandbox" ;;
        blaney|vm-blaney)   HOST="vm-blaney" ;;
        *) echo "Unknown VM: '$NAME'"; usage ;;
      esac

      export NIXPKGS_ALLOW_UNFREE=1
      mkdir -p "$VMDIR"
      cd "$VMDIR"

      DISK="$VMDIR/$HOST.qcow2"
      if [ "$CLEAN" -eq 1 ] && [ -e "$DISK" ]; then
        echo "--- Discarding $DISK for a clean boot ---"
        rm -f "$DISK"
      fi

      echo "--- Building $HOST VM ---"
      nixos-rebuild build-vm --flake "$CONFIG#$HOST" --impure --max-jobs auto --cores 0

      echo "--- Launching $HOST (disk: $DISK; login password: vm) ---"
      NIX_DISK_IMAGE="$DISK" exec ./result/bin/run-*-vm
    '')
  ]) ++ (lib.optionals cfg.user.updateCmdPermission [
    # --- Conditional Commands ---
    # These will be included only if cfg.user.updateCmdPermission is true.
    
    (pkgs.writeShellScriptBin "flake-update" ''
      #!${pkgs.stdenv.shell}
      set -e
      echo "--- Updating Flake Inputs ---"

      ${worktreeLib}

      # Update the lock file of the worktree you are standing in. Pinned to the main
      # checkout this would silently edit another session's flake.lock.
      NIXOS_CONFIG_DIR=$(wt_flake_dir)

      if [ ! -d "$NIXOS_CONFIG_DIR" ]; then
        echo "Error: Configuration directory '$NIXOS_CONFIG_DIR' does not exist."
        exit 1
      fi

      if [ ! -f "$NIXOS_CONFIG_DIR/flake.nix" ]; then
        echo "Error: flake.nix not found in '$NIXOS_CONFIG_DIR'."
        exit 1
      fi

      echo "Changing directory to: $NIXOS_CONFIG_DIR"
      cd "$NIXOS_CONFIG_DIR"

      echo "Updating flake inputs..."
      nix flake update

      echo "Flake update complete. Run 'rebuild' or 'upgrade' to apply the changes to your system."
    '')

    (pkgs.writeShellScriptBin "upgrade" ''
      #!${pkgs.stdenv.shell}
      set -e
      echo "--- Upgrading System (Update Flake Inputs & Rebuild) ---"

      TAKE=0
      for arg in "$@"; do
        case "$arg" in
          --take) TAKE=1 ;;
          *) echo "upgrade: unknown option '$arg'" >&2; exit 1 ;;
        esac
      done

      ${worktreeLib}

      FLAKE_DIR=$(wt_flake_dir)
      wt_require_owner "$FLAKE_DIR" "$TAKE"
      FLAKE_PATH="$FLAKE_DIR#${hostName}"

      echo "Upgrading system for host: '${hostName}'"
      echo "This will update all flake inputs and then rebuild the system."
      echo "Using flake: $FLAKE_PATH"

      # This used to pass --upgrade to nixos-rebuild, which does nothing for a
      # flake-based system: --upgrade only runs `nix-channel --update`. 26.05's
      # rewritten nixos-rebuild says so out loud ("'--upgrade(-all)' flag has no
      # effect for flake-based systems") — before that it failed silently, so
      # `upgrade` was only ever a rebuild. Update the inputs explicitly instead,
      # the same way the `flake-update` command does.
      echo "Updating flake inputs..."
      cd "$FLAKE_DIR"
      nix flake update

      wt_lock
      wt_sudo_rebuild "$FLAKE_DIR" switch --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
      wt_claim "$FLAKE_DIR"
      echo "System upgrade complete."
    '')
  ]) ++ (lib.optionals (cfg.user.name == "insideabush") [
    # --- Blaney (insideabush) helper commands ---
    # Deterministic, non-technical-friendly tools. Gated to insideabush; do NOT
    # use updateCmdPermission here (it is false on blaney-pc).

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

      echo
      echo "What do you want Claude to work on?"
      for i in "''${!TITLES[@]}"; do
        printf "  %d) %s\n" $((i + 1)) "''${TITLES[$i]}"
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

      echo
      echo "Starting Claude on: $TITLE"
      echo

      # Preface prompt — keep in sync with the blaney-pc rules in CLAUDE.md.
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

      exec sudo claude "$PROMPT"
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

      FIX THINGS WITH CLAUDE
        blaney-todo            See tasks Lando left you and have Claude do one
        ccn                    Open Claude in the config folder
        ccnc                   Open Claude and continue your last chat
        ccnr                   Open Claude and pick a past chat to resume
        claude-rebuild-failed  Ask Claude to fix a failed rebuild and make a PR

      OTHER
        rebuild-test   Try a rebuild temporarily (undone on reboot)
        ipr            Open the input-remapper (button remap) app
        blaney-help    Show this list again
        sync           Old name for "update" — still works, but use update
      EOF
    '')
  ]);

  # State for the parallel-worktree commands above. The owner record must survive a
  # reboot (the activated generation does), so it lives in /var/lib rather than /run.
  # The lock file is group-writable because `rebuild` runs as the user and only
  # escalates for nixos-rebuild itself.
  systemd.tmpfiles.rules = [
    "d ${wtStateDir} 0755 root root -"
    "f ${wtLockFile} 0664 root ${userGroup} -"
  ];
}