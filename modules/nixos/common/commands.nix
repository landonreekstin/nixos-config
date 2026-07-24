# ~/nixos-config/modules/nixos/common/commands.nix
{ config, pkgs, lib, ... }:

let
  # Retrieve values from custom options. These must be set in the host's specific configuration.
  cfg = config.customConfig;
  nixosConfigDir = "${cfg.user.home}/nixos-config"; # Path to the cloned Git repository
  hostName = cfg.system.hostName;

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
    git # Ensure git is available for the 'sync' command

    post-install-script

    (writeShellScriptBin "sync" ''
      #!${stdenv.shell}
      set -e # Exit immediately if a command exits with a non-zero status

      echo "--- Syncing NixOS Configuration ---"
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
          echo "Sync complete (beta branch: $BETA_BRANCH)."
          exit 0
        fi
        echo "--- No update branch found, falling back to main ---"
      ''}

      echo "Attempting to pull latest changes..."
      # Try a simple pull first
      if ! git pull; then
        echo "Git pull failed. This might be due to local changes."
        echo "Attempting to stash local changes and pull again..."
        if git stash push -m "Autostash before sync command"; then
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
          echo "Error: Git stash failed. Please resolve local changes in $NIXOS_CONFIG_DIR manually and try syncing again."
          exit 1
        fi
      fi
      echo "Sync complete."
    '')

    (writeShellScriptBin "rebuild" ''
      #!${stdenv.shell}
      set -e
      echo "--- Rebuilding NixOS Configuration ---"
      FLAKE_PATH="${nixosConfigDir}#${hostName}" # Value injected by Nix

      echo "Rebuilding NixOS configuration for host: '${hostName}'"
      echo "Using flake: $FLAKE_PATH"

      sudo nixos-rebuild switch --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
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

    (writeShellScriptBin "rebuild-test" ''
      #!${stdenv.shell}
      set -e
      echo "--- Testing NixOS Configuration (no boot entry) ---"
      FLAKE_PATH="${nixosConfigDir}#${hostName}" # Value injected by Nix

      echo "Activating config for host: '${hostName}' (reverts on reboot)"
      echo "Using flake: $FLAKE_PATH"

      sudo nixos-rebuild test --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
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
    
    (pkgs.writeShellScriptBin "update" ''
      #!${pkgs.stdenv.shell}
      set -e
      echo "--- Updating Flake Inputs ---"
      NIXOS_CONFIG_DIR="${nixosConfigDir}" # Value injected by Nix

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
      FLAKE_PATH="${nixosConfigDir}#${hostName}" # Value injected by Nix

      echo "Upgrading system for host: '${hostName}'"
      echo "This will update all flake inputs and then rebuild the system."
      echo "Using flake: $FLAKE_PATH"

      sudo nixos-rebuild switch --upgrade --flake "$FLAKE_PATH" --impure --max-jobs auto --cores 0
      echo "System upgrade complete."
    '')
  ]);
}