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
    # NixOS Post-Install Setup Script (v2 - with Git Automation)
    # =============================================================================

    # --- Step 1: Move Configuration ---
    if [[ ! -d "/etc/nixos" ]]; then
      echo "✅ Configuration already moved. Proceeding to Git setup."
    else
      echo "--- Starting Post-Install Setup ---"
      if [[ -d "$HOME/nixos-config" ]]; then
        echo "ℹ️ Found an existing '$HOME/nixos-config'. Removing it for a clean move."
        rm -rf "$HOME/nixos-config"
      fi
      echo "Moving system configuration from /etc/nixos to $HOME/nixos-config..."
      sudo mv /etc/nixos "$HOME/nixos-config"
      echo "Changing ownership to user '$(whoami)'..."
      sudo chown -R "$(whoami):$(id -gn)" "$HOME/nixos-config"
      echo "✅ Configuration successfully moved to ~/nixos-config."
    fi
    
    # Change into the configuration directory for all subsequent git commands
    cd "$HOME/nixos-config"

    # --- Step 2: SSH Key Setup ---
    echo ""
    echo "--- GitHub SSH Key Setup ---"
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

    if [ -f "$SSH_KEY_PATH" ]; then
      echo "ℹ️ SSH key already exists at $SSH_KEY_PATH. Skipping generation."
    else
      echo "Generating a new SSH key..."
      # Generate a key with a generic comment and no passphrase for automation
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

    # --- Step 3: Git Operations ---
    echo ""
    echo "--- Finalizing Git Configuration ---"
    
    echo "Testing SSH connection to GitHub..."
    # Use -o StrictHostKeyChecking=accept-new to auto-accept GitHub's host key
    if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
      echo "✅ SSH connection to GitHub successful."
    else
      echo "❌ SSH connection to GitHub failed. Please check the key and try again."
      exit 1
    fi

    # Convert remote URL from HTTPS to SSH if necessary
    CURRENT_REMOTE=$(git remote get-url origin)
    if [[ "$CURRENT_REMOTE" == https* ]]; then
      echo "Converting Git remote from HTTPS to SSH..."
      SSH_REMOTE=$(echo "$CURRENT_REMOTE" | sed 's|https://github.com/|git@github.com:|')
      git remote set-url origin "$SSH_REMOTE"
      echo "✅ Remote URL updated."
    fi

    # Add, commit, and push the hardware configuration
    echo "Adding and committing hardware configuration..."
    git add "hosts/$(hostname)/hardware-configuration.nix"
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

      sudo nixos-rebuild switch --flake "$FLAKE_PATH"
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