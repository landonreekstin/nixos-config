#!/usr/bin/env bash

# =============================================================================
# NixOS Remote Deployer (v1 — nixos-anywhere)
# =============================================================================
# Runs on the ADMIN machine (gaming-pc). Deploys NixOS to a target over SSH.
# The target must be running a live Linux environment with SSH enabled as root.
# Use the custom installer ISO from this flake for the easiest setup:
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
#
# Prerequisites:
#   - sops, ssh-to-age (auto-loaded via nix shell if missing)
#   - Admin age key at ~/.config/sops/age/keys.txt
#   - Target accessible via SSH on the provided IP
#
# Usage:
#   ./scripts/deploy-host.sh <hostname> <target-ip> [ssh-port]
# =============================================================================
set -euo pipefail

CONFIG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_NAME="${1:-}"
TARGET_IP="${2:-}"
SSH_PORT="${3:-22}"

if [[ -z "$HOST_NAME" || -z "$TARGET_IP" ]]; then
    echo "Usage: $0 <hostname> <target-ip> [ssh-port]"
    echo ""
    echo "Examples:"
    echo "  $0 mini-server 192.168.100.103"
    echo "  $0 aj-laptop 192.168.1.55"
    echo "  $0 aj-laptop 10.10.0.5 22   # via WireGuard"
    exit 1
fi

# --- Bootstrap required tools ---
_MISSING=()
command -v sops        &>/dev/null || _MISSING+=(nixpkgs#sops)
command -v ssh-to-age  &>/dev/null || _MISSING+=(nixpkgs#ssh-to-age)
if [[ ${#_MISSING[@]} -gt 0 && -z "${_TOOLS_LOADED:-}" ]]; then
    echo "Loading missing tools: ${_MISSING[*]}"
    export _TOOLS_LOADED=1
    exec nix shell --extra-experimental-features "nix-command flakes" \
        "${_MISSING[@]}" --command "$0" "$@"
fi

ADMIN_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

# --- Pre-flight checks ---
echo "--- Pre-flight checks ---"
[[ -f "$CONFIG_ROOT/hosts/$HOST_NAME/default.nix" ]] || \
    { echo "❌ No host config: hosts/$HOST_NAME/default.nix"; exit 1; }
grep -qE "^\s+-\s+&${HOST_NAME}\s+" "$CONFIG_ROOT/.sops.yaml" || \
    { echo "❌ '$HOST_NAME' not in .sops.yaml — add the anchor and creation rule first"; exit 1; }
[[ -f "$ADMIN_AGE_KEY_FILE" ]] || \
    { echo "❌ Admin age key not found at $ADMIN_AGE_KEY_FILE"; exit 1; }
echo "✅ Pre-flight checks passed."

# --- Temp dir for files injected into target filesystem ---
EXTRA_FILES=$(mktemp -d)
trap 'rm -rf "$EXTRA_FILES"' EXIT
mkdir -p "$EXTRA_FILES/etc/ssh"

# --- Step 1: Generate SSH host key ---
echo ""
echo "--- Generating SSH host key ---"
if [[ -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" ]]; then
    echo "ℹ️  Reusing existing key in temp dir."
else
    ssh-keygen -t ed25519 \
        -f "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key" \
        -N "" -C "root@${HOST_NAME}" -q
    chmod 600 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key"
    chmod 644 "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub"
fi
echo "✅ SSH host key ready."

# --- Step 2: Derive host age key & update .sops.yaml ---
echo ""
echo "--- Updating .sops.yaml ---"
HOST_AGE_KEY=$(ssh-to-age < "$EXTRA_FILES/etc/ssh/ssh_host_ed25519_key.pub")
echo "   Host age key: $HOST_AGE_KEY"
PLACEHOLDER="age1PLACEHOLDER_${HOST_NAME}"
if grep -q "$PLACEHOLDER" "$CONFIG_ROOT/.sops.yaml"; then
    sed -i "s|${PLACEHOLDER}|${HOST_AGE_KEY}|" "$CONFIG_ROOT/.sops.yaml"
    echo "✅ Replaced placeholder with real age key."
elif grep -q "$HOST_AGE_KEY" "$CONFIG_ROOT/.sops.yaml"; then
    echo "ℹ️  Age key already present (re-deploy or key unchanged)."
else
    echo "❌ .sops.yaml has neither placeholder ('$PLACEHOLDER') nor the current key."
    echo "   Update .sops.yaml manually and re-run."
    exit 1
fi

# --- Step 3: Read host password configuration ---
echo ""
echo "--- Reading host config ---"
_nix_eval() {
    nix --extra-experimental-features "nix-command flakes" eval --impure \
        ".#nixosConfigurations.${HOST_NAME}.config.$1" 2>/dev/null || echo "false"
}
SOPS_PASSWORD_ENABLED=$(_nix_eval "customConfig.user.sopsPassword")
SUDO_PASSWORD_ENABLED=$(_nix_eval "customConfig.user.sudoPassword")
HOST_USER=$(_nix_eval "customConfig.user.name")
HOST_USER="${HOST_USER//\"/}"   # strip surrounding quotes from nix eval output
echo "   user:          $HOST_USER"
echo "   sopsPassword:  $SOPS_PASSWORD_ENABLED"
echo "   sudoPassword:  $SUDO_PASSWORD_ENABLED"

if [[ "$SOPS_PASSWORD_ENABLED" != "true" ]]; then
    echo ""
    echo "⚠️  WARNING: sopsPassword = false for '$HOST_NAME'."
    echo "   After install, set the password manually:"
    echo "   ssh root@$TARGET_IP 'passwd $HOST_USER'"
fi

# --- Step 4: Gather passwords & update secrets file ---
SECRETS_FILE="$CONFIG_ROOT/secrets/$HOST_NAME.yaml"

if [[ "$SOPS_PASSWORD_ENABLED" == "true" ]]; then
    echo ""
    echo "--- Gathering passwords ---"
    echo "🔑 LOGIN password for '$HOST_USER':"
    while true; do
        read -s -p "   Enter: " _password; echo
        read -s -p "   Confirm: " _confirm; echo
        [[ "$_password" == "$_confirm" ]] && break
        echo "❌ Mismatch — try again."
    done
    PASSWORD_HASH=$(openssl passwd -6 "$_password")
    echo "✅ Login password hash generated."

    if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
        echo ""
        echo "🔑 SUDO/ROOT password for '$HOST_USER' (separate from login):"
        while true; do
            read -s -p "   Enter: " _sudo_pw; echo
            read -s -p "   Confirm: " _sudo_confirm; echo
            [[ "$_sudo_pw" == "$_sudo_confirm" ]] && break
            echo "❌ Mismatch — try again."
        done
        ROOT_HASH=$(openssl passwd -6 "$_sudo_pw")
        echo "✅ Sudo password hash generated."
    fi

    echo ""
    if [[ -f "$SECRETS_FILE" ]]; then
        # Existing secrets file: rotate to include the new host key, then set passwords.
        echo "--- Updating existing secrets file ---"
        SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
            sops updatekeys -y "$SECRETS_FILE"
        SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
            sops --set '["user-password-hash"] "'"$PASSWORD_HASH"'"' "$SECRETS_FILE"
        if [[ "$SUDO_PASSWORD_ENABLED" == "true" ]]; then
            SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
                sops --set '["root-password-hash"] "'"$ROOT_HASH"'"' "$SECRETS_FILE"
        fi
        echo "✅ Secrets file updated (re-encrypted for $HOST_NAME)."
    else
        # New secrets file: create and encrypt using .sops.yaml creation rules.
        # Encrypts to public keys only — admin private key not required.
        echo "--- Creating secrets file ---"
        {
            printf 'user-password-hash: "%s"\n' "$PASSWORD_HASH"
            [[ "$SUDO_PASSWORD_ENABLED" == "true" ]] && \
                printf 'root-password-hash: "%s"\n' "$ROOT_HASH"
        } > "$SECRETS_FILE"
        SOPS_AGE_KEY_FILE="$ADMIN_AGE_KEY_FILE" \
            sops --encrypt -i "$SECRETS_FILE"
        echo "✅ Secrets file created and encrypted."
    fi

    git -C "$CONFIG_ROOT" add "$SECRETS_FILE"
fi

git -C "$CONFIG_ROOT" add "$CONFIG_ROOT/.sops.yaml"

# --- Step 5: Deploy via nixos-anywhere ---
HW_CONFIG_PATH="$CONFIG_ROOT/hosts/$HOST_NAME/hardware-configuration.nix"
echo ""
echo "--- Deploying $HOST_NAME → $TARGET_IP:$SSH_PORT ---"
echo "    This will WIPE and repartition the target disk."
read -p "    ARE YOU SURE? (y/N) " -n 1 -r; echo
[[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
echo ""

nix run --extra-experimental-features "nix-command flakes" \
    github:nix-community/nixos-anywhere -- \
    --flake "$CONFIG_ROOT#$HOST_NAME" \
    --extra-files "$EXTRA_FILES" \
    --generate-hardware-config "nixos-generate-config --no-filesystems" \
    --hardware-config-path "$HW_CONFIG_PATH" \
    -p "$SSH_PORT" \
    root@"$TARGET_IP"

# --- Done ---
echo ""
echo "✅ $HOST_NAME deployed successfully and is rebooting."
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "1. Commit the results from this machine (gaming-pc):"
echo "   git -C $CONFIG_ROOT add \\"
echo "     hosts/$HOST_NAME/hardware-configuration.nix \\"
echo "     secrets/$HOST_NAME.yaml \\"
echo "     .sops.yaml"
echo "   git -C $CONFIG_ROOT commit -m 'feat($HOST_NAME): deploy — hardware config and age key'"
echo "   git -C $CONFIG_ROOT push"
echo ""
if [[ "$SOPS_PASSWORD_ENABLED" != "true" ]]; then
    echo "2. Set user password on the running system:"
    echo "   ssh root@$TARGET_IP 'passwd $HOST_USER'"
    echo ""
fi
echo "ℹ️  On lando's machines: run 'post-install' on $HOST_NAME to set up GitHub SSH access."
