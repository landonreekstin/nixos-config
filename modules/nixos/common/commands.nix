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
    # NixOS Post-Install Setup Script (v4.1 - Hardcoded Repo)
    # =============================================================================

    # --- Configuration ---
    # The Git repository URL is now hardcoded for simplicity.
    GIT_REPO_URL="git@github.com:landonreekstin/nixos-config.git"

    # --- Pre-flight Checks ---
    if [[ "$EUID" -eq 0 ]]; then
      echo "❌ This script should be run as your normal user, not as root."
      exit 1
    fi

    # --- Step 1: Clone the True Source Repository ---
    echo "--- Cloning from $GIT_REPO_URL ---"
    
    if [[ -d "$HOME/nixos-config" ]]; then
        echo "ℹ️ Found an existing '$HOME/nixos-config'. Removing it for a clean clone."
        rm -rf "$HOME/nixos-config"
    fi

    git clone "$GIT_REPO_URL" "$HOME/nixos-config"
    cd "$HOME/nixos-config"
    echo "✅ Repository cloned successfully to ~/nixos-config."
    echo "-----------------------------------------"

    # --- Step 2: Re-generate Hardware Configuration ---
    echo "--- Generating final hardware configuration on the new system ---"
    
    DEST_HARDWARE_CONFIG="$HOME/nixos-config/hosts/$(hostname)/hardware-configuration.nix"
    
    sudo nixos-generate-config --no-filesystems
    sudo mv /etc/nixos/hardware-configuration.nix "$DEST_HARDWARE_CONFIG"
    sudo chown "$(whoami):$(id -gn)" "$DEST_HARDWARE_CONFIG"
    sudo rm -rf /etc/nixos
    echo "✅ Hardware configuration generated and moved successfully."
    echo "----------------------------------------------------------"

    # --- Step 3: SSH Key and Git Push Automation ---
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
    
    echo "Testing SSH connection to GitHub..."
    if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
      echo "✅ SSH connection to GitHub successful."
    else
      echo "❌ SSH connection to GitHub failed. Please check the key and try again."
      exit 1
    fi

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

      sudo nixos-rebuild switch --flake "$FLAKE_PATH" --impure
      echo "Rebuild complete."
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

      sudo nixos-rebuild switch --upgrade --flake "$FLAKE_PATH"
      echo "System upgrade complete."
    '')
  ]);
}