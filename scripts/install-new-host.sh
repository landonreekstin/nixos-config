#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v2 - Compatible)
#
# This script automates the installation of a new NixOS host. It uses a
# trap-based backup and restore mechanism to be compatible with older
# nixos-install versions that lack the --apply-arg-file flag.
# =============================================================================

# Stop immediately if any command fails
set -e

# --- Configuration ---
CONFIG_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
SECRET_FILE="/tmp/secret-password"
HOST_NAME="$1" # Get hostname from the first argument

# --- File Paths ---
HOST_CONFIG_FILE="$CONFIG_ROOT/hosts/$HOST_NAME/default.nix"
BACKUP_FILE="$HOST_CONFIG_FILE.bak" # Backup of the original config

# --- Safety Trap ---
# This command is GUARANTEED to run when the script exits for any reason.
# It restores the original configuration file, ensuring the git repo is clean.
trap 'echo; echo "--- Restoring original configuration ---"; mv -f "$BACKUP_FILE" "$HOST_CONFIG_FILE" && echo "✅ Restore complete."; exit' EXIT HUP INT QUIT PIPE TERM

# --- Pre-flight Checks ---
# (Checks are the same as before, condensed for clarity)
echo "--- Running Pre-flight Checks ---"
if [[ "$EUID" -ne 0 ]]; then echo "❌ Error: Must be run as root."; exit 1; fi
if [[ -z "$HOST_NAME" ]]; then echo "❌ Error: No hostname specified."; exit 1; fi
if ! mountpoint -q /mnt; then echo "❌ Error: /mnt is not mounted."; exit 1; fi
if [[ ! -f "$HOST_CONFIG_FILE" ]]; then echo "❌ Error: Host config not found at $HOST_CONFIG_FILE"; exit 1; fi
echo "✅ Pre-flight checks passed."
echo "---------------------------------"

# --- Hardware Configuration ---
# (This section is now improved to avoid overwriting by default)
echo "--- Generating Hardware Configuration ---"
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then
    echo "ℹ️ Hardware configuration already exists. Skipping generation."
else
    nixos-generate-config --root /mnt
    mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
    rm /mnt/etc/nixos/configuration.nix
    echo "✅ Hardware configuration generated and moved."
fi
echo "---------------------------------------"


# --- Gather Information ---
echo "--- Gathering User Information ---"
echo "🔑 Please choose an initial password for the user being created on '$HOST_NAME'."
read -s -p "   Enter password: " password
echo
read -s -p "Confirm password: " password_confirm
echo
if [[ "$password" != "$password_confirm" ]]; then echo "❌ Error: Passwords do not match."; exit 1; fi
echo "$password" > "$SECRET_FILE"
echo "✅ Secret password file created."
echo "----------------------------------"

# --- Prepare Installation (The "Swap" Method) ---
echo "--- Preparing Installation ---"
echo "Backing up original configuration to $BACKUP_FILE..."
mv "$HOST_CONFIG_FILE" "$BACKUP_FILE"
echo "✅ Backup complete."

echo "Creating temporary installation config..."
# Now, we write the wrapper content directly into the real config file's location.
# It imports the BACKUP file, so all your original settings are still included.
cat > "$HOST_CONFIG_FILE" <<EOF
# DO NOT EDIT - This file is temporary and will be restored by the script.
{ ... }: {
  imports = [
    # Import the actual configuration from the backup
    "$BACKUP_FILE"
  ];

  # Override with settings for the initial installation.
  customConfig.user = {
    isNewHost = true;
    initialPasswordFile = "$SECRET_FILE";
  };
}
EOF
echo "✅ Temporary config created."
echo "----------------------------"

# --- Execute Installation ---
echo "🚀 Starting NixOS installation for host: $HOST_NAME..."
# The command is now simpler and compatible, but we MUST use --impure
# so it can see the untracked hardware-configuration.nix file.
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure

# --- Cleanup ---
# The 'trap' at the top of the script handles all cleanup automatically.
# When this script ends, the trap will run and restore your original file.
echo "✅ Installation command finished."