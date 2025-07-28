#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v3 - Disko Automated)
#
# This script fully automates the installation of a new NixOS host.
# It uses Disko to partition drives, then proceeds with the installation.
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
trap 'echo; echo "--- Restoring original configuration ---"; if [ -f "$BACKUP_FILE" ]; then mv -f "$BACKUP_FILE" "$HOST_CONFIG_FILE"; echo "✅ Restore complete."; fi; exit' EXIT HUP INT QUIT PIPE TERM

# --- Pre-flight Checks ---
echo "--- Running Pre-flight Checks ---"
if [[ "$EUID" -ne 0 ]]; then echo "❌ Error: Must be run as root."; exit 1; fi
if [[ -z "$HOST_NAME" ]]; then echo "❌ Error: No hostname specified. Usage: $0 <hostname>"; exit 1; fi
if [[ ! -f "$HOST_CONFIG_FILE" ]]; then echo "❌ Error: Host config not found at $HOST_CONFIG_FILE"; exit 1; fi
echo "✅ Pre-flight checks passed."
echo "---------------------------------"


# --- DISKO AUTOMATED PARTITIONING ---
echo "--- Starting Automated Disk Partitioning with Disko ---"
echo "ℹ️ Disko will read the configuration for '$HOST_NAME' from your flake."
echo "⚠️ WARNING: This will WIPE the target disk defined in your host's config."
read -p "ARE YOU SURE YOU WANT TO CONTINUE? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# This command runs disko, which finds the config in your flake for the specified
# host and applies it, partitioning, formatting, and mounting everything to /mnt.
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode disko "$CONFIG_ROOT#$HOST_NAME"

echo "✅ Disko partitioning complete. Disks are now mounted at /mnt."
echo "---------------------------------------------------------"


# --- Hardware Configuration Generation ---
echo "--- Generating Hardware Configuration ---"
# This now runs on the freshly prepared /mnt directory
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then
    echo "ℹ️ Hardware configuration already exists. Skipping generation."
else
    nixos-generate-config --no-filesystems --root /mnt
    mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
    rm /mnt/etc/nixos/configuration.nix
    echo "✅ Hardware configuration generated and moved."
fi
echo "---------------------------------------"


# --- Gather User Information ---
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
# We MUST use --impure so the flake can see the untracked, newly generated
# hardware-configuration.nix file.
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure

# --- Cleanup ---
# The 'trap' at the top of the script handles all cleanup automatically.
# When this script ends, the trap will run and restore your original file.
echo "✅ Installation command finished."
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as the new user."
echo "2. Run the following command to finalize your configuration setup:"
echo "   post-install"