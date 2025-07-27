#!/usr/bin/env bash

# =============================================================================
# NixOS Post-Install Setup Script
#
# This script moves the system configuration from /etc/nixos to the user's
# home directory (~/nixos-config) and sets the correct ownership.
#
# It is idempotent and can be run multiple times without harm.
# Run this as the normal user, NOT as root.
# =============================================================================

set -e

# --- Pre-flight Checks ---

# 1. Ensure the script is NOT run as root
if [[ "$EUID" -eq 0 ]]; then
  echo "❌ This script should be run as your normal user, not as root."
  exit 1
fi

# 2. Check if the work is already done
if [[ ! -d "/etc/nixos" ]]; then
  echo "✅ Configuration already moved. Nothing to do."
  exit 0
fi

echo "--- Starting Post-Install Setup ---"

# 3. Ensure the destination is clean to prevent nesting issues.
#    This was the likely cause of the original problem.
if [[ -d "$HOME/nixos-config" ]]; then
    echo "ℹ️ Found an existing '$HOME/nixos-config'. Removing it for a clean move."
    rm -rf "$HOME/nixos-config"
fi

# 4. Perform the move using sudo.
echo "Moving system configuration from /etc/nixos to $HOME/nixos-config..."
sudo mv /etc/nixos "$HOME/nixos-config"

# 5. Take ownership of the moved directory.
echo "Changing ownership to user '$(whoami)'..."
sudo chown -R "$(whoami):$(id -gn)" "$HOME/nixos-config"

echo "✅ All done. Your configuration is now at ~/nixos-config."