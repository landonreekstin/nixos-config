#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v5 - Correct Order of Operations)
# =============================================================================
set -e

# --- Configuration & Paths ---
CONFIG_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
HOST_NAME="$1"
SECRET_FILE="/tmp/secret-password" 

# --- Pre-flight Checks ---
echo "--- Running Pre-flight Checks ---"
if [[ "$EUID" -ne 0 ]]; then echo "❌ Error: Must be run as root."; exit 1; fi
if [[ -z "$HOST_NAME" ]]; then echo "❌ Error: No hostname specified. Usage: $0 <hostname>"; exit 1; fi
if [[ ! -f "$CONFIG_ROOT/hosts/$HOST_NAME/default.nix" ]]; then echo "❌ Error: Host config not found for '$HOST_NAME'"; exit 1; fi
echo "✅ Pre-flight checks passed."
echo "---------------------------------"

# --- Step 1: DRAFT Hardware Configuration Generation ---
echo "--- Generating DRAFT Hardware Configuration (so disko can evaluate) ---"
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then
    echo "ℹ️ A hardware configuration already exists. Skipping draft generation."
else
    # We generate a temporary config based on the LIVE installer environment.
    # This file MUST exist for the disko evaluation to pass.
    # We do NOT use --root /mnt because nothing is mounted yet.
    nixos-generate-config --no-filesystems
    mv /etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
    rm /etc/nixos/configuration.nix
    echo "✅ Draft hardware configuration created."
fi
echo "---------------------------------------------------------------------"

# --- Step 2: DISKO AUTOMATED PARTITIONING ---
echo "--- Starting Automated Disk Partitioning with Disko ---"
echo "ℹ️ This will WIPE the target disk defined in your host's config."
read -p "ARE YOU SURE YOU WANT TO CONTINUE? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode disko --flake "$CONFIG_ROOT#$HOST_NAME"

echo "✅ Disko partitioning complete. Disks are now mounted at /mnt."
echo "---------------------------------------------------------"

# --- Step 3: FINAL Hardware Configuration Generation ---
echo "--- Generating FINAL Hardware Configuration ---"
# Now that /mnt is prepared, we run the command again on the REAL mountpoint
# to get the most accurate configuration, overwriting the draft.
nixos-generate-config --no-filesystems --root /mnt
mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
rm /mnt/etc/nixos/configuration.nix
echo "✅ Final hardware configuration generated."
echo "---------------------------------------"

# --- Step 4: Gather User Information ---
echo "--- Gathering User Information ---"
echo "🔑 Please choose an initial password for the user being created on '$HOST_NAME'."
read -s -p "   Enter password: " password
echo
read -s -p "Confirm password: " password_confirm
echo
if [[ "$password" != "$password_confirm" ]]; then echo "❌ Error: Passwords do not match."; exit 1; fi
echo "$password" > "$SECRET_FILE"
echo "✅ Secret password file created at '$SECRET_FILE'."
echo "----------------------------------"

# --- Step 5: Execute Installation ---
echo "🚀 Installing NixOS for host: $HOST_NAME..."
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure

# --- Cleanup ---
rm -f "$SECRET_FILE"
echo "✅ Installation complete and temporary secret file removed."
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as the new user."
echo "2. Run the command 'post-install' to finalize setup and push to Git."