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
git add "$HARDWARE_CONFIG_PATH"
git config user.name "NixOS Installer"
git config user.email "installer@nixos.org"
git commit -m "feat(hosts): Add temporary hardware config for installation"
echo "✅ Local commit successful."
echo "--------------------------------------------------------------"

# --- Step 5: Gather User Information ---
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

  while true; do
    read -s -p "   Enter sudo password: " sudo_password
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
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure
echo "✅ Base system installed."

# --- Step 7: Set Passwords on the New System ---
echo "--- Setting User Passwords ---"

# Set the primary (login) password using chpasswd inside the new system.
echo "Entering the new system to set LOGIN password for '$USER_NAME'..."
nixos-enter --root /mnt --command "echo \"$USER_NAME:$password\" | chpasswd"
echo "✅ Login password for '$USER_NAME' has been set successfully."

# If the sudo password feature is enabled, create the separate password file.
if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
  echo "Creating separate SUDO password file..."
  # MODIFICATION: This command is now run from the installer environment,
  # which already has experimental features enabled. It targets the mounted filesystem.
  nix --extra-experimental-features "nix-command flakes" run nixpkgs#apacheHttpd.tools -- htpasswd -cbB "/mnt/etc/security/sudo_passwd" "$USER_NAME" "$sudo_password"
  echo "✅ Sudo password for '$USER_NAME' has been set successfully."
fi
echo "----------------------------------"

echo "🎉 Installation complete!"
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as '$USER_NAME'."
echo "2. Run 'post-install' to finalize setup, correct the Git history, and push."