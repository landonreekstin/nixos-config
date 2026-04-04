#!/usr/bin/env bash

# =============================================================================
# NixOS Flake-Based Host Installer (v12 - SOPS-native password bootstrapping)
# =============================================================================
# User passwords are no longer set imperatively via chpasswd. Instead, the
# installer generates SSH host keys early, derives the host's age key, updates
# .sops.yaml, and encrypts password hashes into the host's secrets file. The
# NixOS configuration then applies them declaratively via sops-nix.
#
# Prerequisites on the installer environment:
#   - sops      (or will be loaded via `nix shell`)
#   - ssh-to-age (or will be loaded via `nix shell`)
#   - openssl (for password hashing; available in all NixOS environments)
#
# Usage:
#   sudo ./install-new-host.sh <hostname> <username>
#   sudo ./install-new-host.sh --reset
# =============================================================================
set -e

# --- Configuration & Paths ---
CONFIG_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

# --- Bootstrap required tools if not already in PATH ---
# Re-exec inside a nix shell that provides sops and ssh-to-age if missing.
_MISSING=()
command -v sops      &>/dev/null || _MISSING+=(nixpkgs#sops)
command -v ssh-to-age &>/dev/null || _MISSING+=(nixpkgs#ssh-to-age)
if [[ ${#_MISSING[@]} -gt 0 && -z "$_TOOLS_LOADED" ]]; then
    echo "ℹ️  Loading missing tools via nix: ${_MISSING[*]}"
    export _TOOLS_LOADED=1
    exec nix shell --extra-experimental-features "nix-command flakes" \
        "${_MISSING[@]}" --command "$0" "$@"
fi

# --- Cleanup Function & Trap ---
cleanup() {
    echo "--- Running cleanup ---"
    umount -R /mnt 2>/dev/null || true
    echo "✅ Cleanup complete."
}
trap cleanup EXIT

# --- Reset & Update Workflow ---
if [[ "$1" == "--reset" ]]; then
    echo "--- GIT RESET MODE ---"
    read -p "Enter the name of your main branch (e.g., main, master, dev): " main_branch
    if [[ -z "$main_branch" ]]; then echo "❌ Error: Branch name cannot be empty."; exit 1; fi
    echo "This will discard all local changes and reset to origin/${main_branch}."
    read -p "ARE YOU SURE? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
    git fetch origin
    git reset --hard "origin/${main_branch}"
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
  echo "❌ Error: Missing arguments. Usage: $0 <hostname> <username>"; exit 1;
fi
if [[ ! -f "$CONFIG_ROOT/hosts/$HOST_NAME/default.nix" ]]; then
  echo "❌ Error: Host config not found for '$HOST_NAME'"; exit 1;
fi

# Verify the host has an entry (real key or placeholder) in .sops.yaml
if ! grep -qE "^\s+-\s+&${HOST_NAME}\s+" "$CONFIG_ROOT/.sops.yaml"; then
  echo "❌ Error: '$HOST_NAME' has no entry in .sops.yaml."
  echo "   Add the host anchor and creation rules before running the installer."
  exit 1
fi

echo "✅ Pre-flight checks passed."

# --- Step 1: Create Placeholder Hardware Configuration ---
echo "--- Creating placeholder hardware configuration ---"
HARDWARE_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
if [[ -f "$HARDWARE_CONFIG_PATH" ]]; then echo "ℹ️  Hardware configuration already exists. Overwriting."; fi
echo "{}" > "$HARDWARE_CONFIG_PATH"
echo "✅ Placeholder created."

# --- Step 2: DISKO Automated Partitioning ---
echo "--- Starting Automated Disk Partitioning ---"
read -p "ARE YOU SURE YOU WANT TO WIPE THE DISKS for '$HOST_NAME'? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko --flake "$CONFIG_ROOT#$HOST_NAME"
echo "✅ Disko partitioning complete."

# --- Step 2.5: Low-Memory Detection ---
# nixos-install is memory-intensive. On machines with ≤6GB RAM there is no swap
# yet (the swapfile is on the freshly-formatted disk but not active), which can
# cause a hard kernel freeze mid-install. Activate the swapfile now if present,
# and limit nix parallelism to reduce peak memory usage.
NIXOS_INSTALL_EXTRA_ARGS=""
TOTAL_MEM_GB=$(awk '/MemTotal/ { printf "%d", $2 / 1024 / 1024 }' /proc/meminfo)
LOW_MEM_THRESHOLD_GB=6
if [[ "$TOTAL_MEM_GB" -lt "$LOW_MEM_THRESHOLD_GB" ]]; then
    echo "⚠️  Low memory detected: ${TOTAL_MEM_GB}GB RAM (threshold: ${LOW_MEM_THRESHOLD_GB}GB)."
    SWAPFILE="/mnt/.swapvol/swapfile"
    if [[ -f "$SWAPFILE" ]]; then
        swapon "$SWAPFILE"
        echo "✅ Swap activated: $SWAPFILE ($(( $(stat -c %s "$SWAPFILE") / 1024 / 1024 / 1024 ))GB)"
    else
        echo "⚠️  Swapfile not found at $SWAPFILE — host may not have a swap subvolume configured."
    fi
    NIXOS_INSTALL_EXTRA_ARGS="--max-jobs 2 --cores 2"
    echo "   nixos-install will run with: $NIXOS_INSTALL_EXTRA_ARGS"
else
    echo "✅ Memory check passed: ${TOTAL_MEM_GB}GB RAM — no swap activation needed."
fi

# --- Step 3: Final Hardware Configuration Generation ---
echo "--- Generating Final Hardware Configuration ---"
nixos-generate-config --no-filesystems --root /mnt
sudo mv /mnt/etc/nixos/hardware-configuration.nix "$HARDWARE_CONFIG_PATH"
sudo chown "$SUDO_USER:$SUDO_GID" "$HARDWARE_CONFIG_PATH"
sudo rm -rf /mnt/etc/nixos
echo "✅ Final hardware configuration generated."

# --- Step 4: Stage Hardware Config for Flake Visibility ---
echo "--- Staging hardware configuration in Git ---"
git -C "$CONFIG_ROOT" add "$HARDWARE_CONFIG_PATH"
echo "✅ Hardware configuration staged."

# --- Step 5: Generate SSH Host Keys ---
# Pre-generating the SSH host key serves two purposes:
#   1. Allows us to derive the host's age key before nixos-install runs.
#   2. openssh only generates keys that don't already exist, so nixos-install
#      will reuse these keys rather than generate new ones.
echo "--- Generating SSH host keys ---"
mkdir -p /mnt/etc/ssh
if [[ -f /mnt/etc/ssh/ssh_host_ed25519_key ]]; then
    echo "ℹ️  SSH host key already exists, reusing."
else
    ssh-keygen -t ed25519 -f /mnt/etc/ssh/ssh_host_ed25519_key -N "" -C "root@${HOST_NAME}"
    chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
    chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
fi
echo "✅ SSH host keys ready."

# --- Step 6: Extract Host Age Key ---
echo "--- Extracting age key from SSH host key ---"
HOST_AGE_KEY=$(ssh-to-age < /mnt/etc/ssh/ssh_host_ed25519_key.pub)
echo "   Age key: $HOST_AGE_KEY"
echo "✅ Age key extracted."

# --- Step 7: Update .sops.yaml with Real Age Key ---
echo "--- Updating .sops.yaml ---"
PLACEHOLDER="age1PLACEHOLDER_${HOST_NAME}"
if grep -q "$PLACEHOLDER" "$CONFIG_ROOT/.sops.yaml"; then
    sed -i "s|${PLACEHOLDER}|${HOST_AGE_KEY}|" "$CONFIG_ROOT/.sops.yaml"
    echo "✅ Replaced placeholder with real age key."
elif grep -q "$HOST_AGE_KEY" "$CONFIG_ROOT/.sops.yaml"; then
    echo "ℹ️  Age key already present in .sops.yaml (reinstall or key unchanged)."
else
    echo "❌ Error: The entry for '$HOST_NAME' in .sops.yaml has neither the expected"
    echo "   placeholder ('${PLACEHOLDER}') nor the current age key."
    echo "   Update .sops.yaml manually and re-run."
    exit 1
fi

# --- Step 8: Check Host Password Configuration ---
echo "--- Checking password configuration for '$HOST_NAME' ---"
_EVAL_FLAGS="--extra-experimental-features 'nix-command flakes' --impure"

SOPS_PASSWORD_ENABLED=$(
    nix --extra-experimental-features "nix-command flakes" eval --impure \
        ".#nixosConfigurations.${HOST_NAME}.config.customConfig.user.sopsPassword" \
        2>/dev/null || echo "false"
)

SUDO_PASSWORD_ENABLED=$(
    nix --extra-experimental-features "nix-command flakes" eval --impure \
        ".#nixosConfigurations.${HOST_NAME}.config.customConfig.user.sudoPassword" \
        2>/dev/null || echo "false"
)

echo "   sopsPassword:  $SOPS_PASSWORD_ENABLED"
echo "   sudoPassword:  $SUDO_PASSWORD_ENABLED"
echo ""

if [[ "$SOPS_PASSWORD_ENABLED" != "true" ]]; then
    echo "⚠️  WARNING: '$HOST_NAME' has sopsPassword = false."
    echo "   Passwords will be set imperatively via chpasswd (legacy path)."
    echo "   Consider enabling sopsPassword in the host config for a fully declarative setup."
    echo ""
fi

# --- Step 9: Gather Passwords ---
echo "--- Gathering Passwords ---"
echo "🔑 LOGIN password for '$USER_NAME' (used for graphical login / SDDM / screen lock)."

while true; do
    read -s -p "   Enter login password: " password
    echo
    read -s -p "   Confirm login password: " password_confirm
    echo
    [[ "$password" == "$password_confirm" ]] && break
    echo "❌ Passwords do not match. Please try again."
    echo
done
echo "✅ Login password captured."
echo

if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
    echo "🔑 SUDO password for '$USER_NAME' (separate strong password for administrative tasks)."
    echo "   sudo is configured to ask for the ROOT password (rootpw), not the login password."

    while true; do
        read -s -p "   Enter sudo password: " sudo_password
        echo
        read -s -p "   Confirm sudo password: " sudo_password_confirm
        echo
        [[ "$sudo_password" == "$sudo_password_confirm" ]] && break
        echo "❌ Passwords do not match. Please try again."
        echo
    done
    echo "✅ Sudo password captured."
    echo
fi

# --- Step 10: Create SOPS Secrets File (sopsPassword hosts only) ---
if [[ "$SOPS_PASSWORD_ENABLED" == "true" ]]; then
    echo "--- Creating SOPS secrets file ---"
    SECRETS_FILE="$CONFIG_ROOT/secrets/$HOST_NAME.yaml"

    # Generate hashes using openssl (SHA-512-crypt; universally available).
    # NixOS accepts any libc-compatible hash format.
    PASSWORD_HASH=$(openssl passwd -6 "$password")
    echo "✅ Login password hash generated."

    if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
        ROOT_HASH=$(openssl passwd -6 "$sudo_password")
        echo "✅ Sudo (root) password hash generated."
    fi

    if [[ -f "$SECRETS_FILE" ]]; then
        # Update specific keys in an existing encrypted file.
        # Requires the admin age key to decrypt the existing data key first.
        echo "ℹ️  Secrets file already exists — updating password hashes in place."
        SUDO_USER_HOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
        ADMIN_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${SUDO_USER_HOME}/.config/sops/age/keys.txt}"

        if [[ ! -f "$ADMIN_AGE_KEY_FILE" ]]; then
            echo "❌ Error: Admin age key not found at '$ADMIN_AGE_KEY_FILE'."
            echo "   Set SOPS_AGE_KEY_FILE to your age key path and re-run."
            exit 1
        fi

        SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
            sops --set '["user-password-hash"] "'"$PASSWORD_HASH"'"' "$SECRETS_FILE"

        if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
            SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
                sops --set '["root-password-hash"] "'"$ROOT_HASH"'"' "$SECRETS_FILE"
        fi

        echo "✅ Secrets file updated."
    else
        # Create a new encrypted file.
        # Writing to the final path first ensures .sops.yaml creation rules match.
        # No admin private key needed — sops encrypts using recipients' public keys only.
        echo "Creating new secrets file..."
        {
            printf 'user-password-hash: "%s"\n' "$PASSWORD_HASH"
            if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
                printf 'root-password-hash: "%s"\n' "$ROOT_HASH"
            fi
        } > "$SECRETS_FILE"

        # Encrypt in-place using .sops.yaml creation rules
        sops --encrypt -i "$SECRETS_FILE"
        echo "✅ Secrets file created and encrypted."
    fi

    # Stage both the secrets file and the updated .sops.yaml
    git -C "$CONFIG_ROOT" add "secrets/$HOST_NAME.yaml" ".sops.yaml"
    echo "✅ Secrets file and .sops.yaml staged."
    echo
fi

# --- Step 11: Execute NixOS Installation ---
echo "--- Installing NixOS for host: $HOST_NAME ---"
nixos-install --no-root-passwd --flake "$CONFIG_ROOT#$HOST_NAME" --impure $NIXOS_INSTALL_EXTRA_ARGS
echo "✅ Base system installed."

# --- Step 12: Set Passwords (legacy path for non-sops hosts only) ---
if [[ "$SOPS_PASSWORD_ENABLED" != "true" ]]; then
    echo "--- Setting User Passwords (legacy chpasswd) ---"

    echo "Setting LOGIN password for '$USER_NAME'..."
    nixos-enter --root /mnt --command "printf '%s:%s' '$USER_NAME' '$password' | chpasswd"
    echo "✅ Login password set."

    if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
        echo "Setting root (sudo) password..."
        nixos-enter --root /mnt --command "printf '%s:%s' 'root' '$sudo_password' | chpasswd"
        echo "✅ Root password set."
    fi
fi

echo "----------------------------------"
echo "🎉 Installation complete!"
echo ""
echo "🔴 IMPORTANT POST-BOOT STEPS:"
echo "1. Log in as '$USER_NAME'."
if [[ "$SOPS_PASSWORD_ENABLED" == "true" ]]; then
echo "2. Run 'post-install' to finalize setup, correct the Git history, and push"
echo "   (including the updated .sops.yaml and secrets/${HOST_NAME}.yaml)."
else
echo "2. Run 'post-install' to finalize setup, correct the Git history, and push."
echo "   NOTE: Consider enabling sopsPassword for this host to make passwords declarative."
fi
