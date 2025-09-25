#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v10 - Resilient & Idempotent)
# =============================================================================
set -e

# --- Configuration & Paths ---
CONFIG_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/devnull 2>&1 && pwd )"

# --- NEW: Cleanup Function & Trap ---
# This function will be called automatically when the script exits.
cleanup() {
    echo "--- Running cleanup ---"
    # Unmount everything under /mnt recursively. The '|| true' prevents
    # the script from failing if nothing is mounted.
    umount -R /mnt || true
    echo "✅ Cleanup complete."
}
# trap [command] [signal]: Execute a command when a signal is received.
# EXIT is a special signal that fires when the script exits, for any reason.
trap cleanup EXIT

# --- NEW: Reset & Update Workflow ---
# This block allows you to easily reset the repo to pull in fixes.
if [[ "$1" == "--reset" ]]; then
    echo "--- GIT RESET MODE ---"
    read -p "Enter the name of your main branch (e.g., main, master, dev): " main_branch
    if [[ -z "$main_branch" ]]; then
        echo "❌ Error: Branch name cannot be empty."
        exit 1
    fi
    echo "This will discard all local changes and reset to origin/${main_branch}."
    read -p "ARE YOU SURE? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

    # The cleanup trap will handle unmounting first.
    git fetch origin
    git reset --hard "origin/${main_branch}"
    # Remove any untracked files and directories (like a generated hardware-config).
    git clean -fdx
    echo "✅ Git repository has been reset. Now run 'git pull' to get updates."
    exit 0
fi

# --- Main Script Logic ---
HOST_NAME="$1"
USER_NAME="$2"

# --- Pre-flight Checks ---
echo "--- Running Pre-flight Checks ---"
if [[ "$EUID" -ne 0 ]]; then echo "❌ Error: Must be run as root."; exit 1; fi
if [[ -z "$HOST_NAME" || -z "$USER_NAME" ]]; then
  echo "❌ Error: Missing arguments."
  echo "   Usage: $0 <hostname> <username>"
  echo "   To reset and pull fixes, run: $0 --reset"
  exit 1
fi
if [[ ! -f "$CONFIG_ROOT/hosts/$HOST_NAME/default.nix" ]]; then
  echo "❌ Error: Host config not found for '$HOST_NAME'"; exit 1;
fi
echo "✅ Pre-flight checks passed."

# --- Step 1: Create Placeholder Hardware Configuration ---
# This step is now safe to re-run, as a reset will clean the old file.
echo "--- Creating placeholder hardware configuration ---"
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then
    echo "ℹ️ Hardware configuration already exists. Overwriting."
fi
# Always create/overwrite to ensure a clean slate for this step.
echo "{}" > "$HARDWARE_CONFIG_PATH"
echo "✅ Placeholder created."


# --- Step 2: DISKO AUTOMATED PARTITIONING ---
echo "--- Starting Automated Disk Partitioning ---"
echo "⚠️ This is a destructive operation."
read -p "ARE YOU SURE YOU WANT TO WIPE THE DISKS for '$HOST_NAME'? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake "$CONFIG_ROOT#$HOST_NAME"
echo "✅ Disko partitioning complete."

# --- Step 3: FINAL Hardware Configuration Generation ---
echo "--- Generating FINAL Hardware Configuration ---"
nixos-generate-config --no-filesystems --root /mnt
# The file from Step 1 is now overwritten with real hardware data.
sudo mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
sudo chown "$SUDO_USER:$SUDO_GID" "$HARDWARE_CONFIG_PATH"
sudo rm -rf /mnt/etc/nixos
echo "✅ Final hardware configuration generated."

# --- REMOVED: Step 4 (Git Commit) has been removed. ---
# The --impure flag on nixos-install handles the untracked hardware-configuration.nix

# --- Step 5: Gather User Information (Unchanged) ---
# ... (The password gathering logic remains exactly the same) ...
echo "--- Gathering User Information ---"

echo "ℹ️ Checking for separate sudo password configuration..."
SUDO_PASSWORD_ENABLED=$(nix --extra-experimental-features "nix-command flakes" eval ".#nixosConfigurations.$HOST_NAME.config.customConfig.user.sudoPassword")

if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
  echo "✅ Separate sudo password enabled for '$HOST_NAME'."
else
  echo "ℹ️ Using standard user password for sudo."
fi
echo

echo "🔑 Please choose a LOGIN password for the user '$USER_NAME'."
echo "   This will be used for the graphical login and screen locker."

while true; do
  read -s -p "   Enter login password: " password
  echo
  read -s -p "Confirm login password: " password_confirm
  echo

  if [[ "$password" == "$password_confirm" ]]; then
    break
  else
    echo "❌ Error: Passwords do not match. Please try again."
    echo
  fi
done

echo "✅ Login password captured."
echo

if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
  echo "🔑 Please choose a SUDO password for the user '$USER_NAME'."
  echo "   This should be a STRONG password for administrative tasks."

  while true; read -s -p "   Enter sudo password: " sudo_password
    echo
    read -s -p "Confirm sudo password: " sudo_password_confirm
    echo

    if [[ "$sudo_password" == "$sudo_password_confirm" ]]; then
      break
    else
      echo "❌ Error: Passwords do not match. Please try again."
      echo
    fi
  done
  echo "✅ Sudo password captured."
  echo
fi


# --- Step 6: Execute NixOS Installation ---
echo "--- Installing NixOS for host: $HOST_NAME ---"
# The --impure flag is now essential as we are not committing the hardware config.
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure
echo "✅ Base system installed."

# --- Step 7: Set Passwords on the New System (Unchanged) ---
# ... (The password setting logic remains exactly the same) ...
echo "--- Setting User Passwords ---"

echo "Entering the new system to set LOGIN password for '$USER_NAME'..."
nixos-enter --root /mnt --command "echo \"$USER_NAME:$password\" | chpasswd"
echo "✅ Login password for '$USER_NAME' has been set successfully."

if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
  echo "Creating separate SUDO password file..."
  nix --extra-experimental-features "nix-command flakes" run nixpkgs#apacheHttpd.tools -- htpasswd -cbB "/mnt/etc/security/sudo_passwd" "$USER_NAME" "$sudo_password"
  echo "✅ Sudo password for '$USER_NAME' has been set successfully."
fi
echo "----------------------------------"


echo "🎉 Installation complete!"
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as '$USER_NAME'."
echo "2. Run 'post-install <repo-url>' to finalize setup, correct the Git history, and push."