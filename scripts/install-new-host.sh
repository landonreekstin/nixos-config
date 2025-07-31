#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v9 - Local Commit + nixos-enter)
# =============================================================================
set -e

# --- Configuration & Paths ---
CONFIG_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
HOST_NAME="$1"
USER_NAME="$2"

# --- Pre-flight Checks ---
echo "--- Running Pre-flight Checks ---"
if [[ "$EUID" -ne 0 ]]; then echo "❌ Error: Must be run as root."; exit 1; fi
if [[ -z "$HOST_NAME" || -z "$USER_NAME" ]]; then
  echo "❌ Error: Missing arguments. Usage: $0 <hostname> <username>"; exit 1;
fi
if [[ ! -f "$CONFIG_ROOT/hosts/$HOST_NAME/default.nix" ]]; then
  echo "❌ Error: Host config not found for '$HOST_NAME'"; exit 1;
fi
echo "✅ Pre-flight checks passed."

# --- Step 1: Create Placeholder Hardware Configuration ---
echo "--- Creating placeholder hardware configuration ---"
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then
    echo "ℹ️ Hardware configuration already exists. Skipping placeholder."
else
    echo "{}" > "$HARDWARE_CONFIG_PATH"
    echo "✅ Placeholder created."
fi

# --- Step 2: DISKO AUTOMATED PARTITIONING ---
echo "--- Starting Automated Disk Partitioning ---"
read -p "ARE YOU SURE YOU WANT TO WIPE THE DISKS for '$HOST_NAME'? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake "$CONFIG_ROOT#$HOST_NAME"
echo "✅ Disko partitioning complete."

# --- Step 3: FINAL Hardware Configuration Generation ---
echo "--- Generating FINAL Hardware Configuration ---"
nixos-generate-config --no-filesystems --root /mnt
sudo mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
sudo chown "$SUDO_USER:$SUDO_GID" "$HARDWARE_CONFIG_PATH"
sudo rm -rf /mnt/etc/nixos
echo "✅ Final hardware configuration generated."

# --- Step 4: Commit Hardware Config Locally ---
echo "--- Committing hardware configuration to local Git repository ---"
# This step is CRITICAL. It makes the flake "pure" for nixos-install.
git add "$HARDWARE_CONFIG_PATH"
# We must configure a temporary git user for the commit to succeed.
git config user.name "NixOS Installer"
git config user.email "installer@nixos.org"
git commit -m "feat(hosts): Add temporary hardware config for installation"
echo "✅ Local commit successful."
echo "--------------------------------------------------------------"

# --- Step 5: Gather User Information ---
echo "--- Gathering User Information ---"
echo "🔑 Please choose a password for the user '$USER_NAME'."
read -s -p "   Enter password: " password
echo
read -s -p "Confirm password: " password_confirm
echo
if [[ "$password" != "$password_confirm" ]]; then
  echo "❌ Error: Passwords do not match."; exit 1;
fi
echo "✅ Password captured."

# --- Step 6: Execute NixOS Installation ---
echo "--- Installing NixOS for host: $HOST_NAME ---"
# The --impure flag is no longer needed as the repo is now clean,
# but it provides robustness against other potential issues.
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure
echo "✅ Base system installed."

# --- Step 7: Set Password Directly with nixos-enter ---
echo "--- Setting User Password Directly ---"
echo "Entering the new system to set password for '$USER_NAME'..."
nixos-enter --root /mnt --command "echo \"$USER_NAME:$password\" | chpasswd"
echo "✅ Password for '$USER_NAME' has been set successfully."
echo "----------------------------------"

echo "🎉 Installation complete!"
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as '$USER_NAME'."
echo "2. Run 'post-install <repo-url>' to finalize setup, correct the Git history, and push."