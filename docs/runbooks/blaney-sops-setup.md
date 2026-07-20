# Runbook: Complete blaney-pc sops setup (unblocks the WireGuard client)

**Audience:** a Claude Code session running **on blaney-pc**.
**Goal:** give blaney-pc a real sops identity and create its encrypted secret, then open a
PR. This is the last prerequisite for the KDE WireGuard client in **PR #80**
(`feat/wg-clients-lan-access`). This runbook does **not** touch the WireGuard config itself
(that stays in PR #80) — it only establishes the sops identity + secret.

## Why this is needed
blaney-pc has no SSH host key (it runs with `services.ssh.enable = false`, and NixOS only
generates host keys when openssh is enabled). sops derives every host's age identity from
`/etc/ssh/ssh_host_ed25519_key` (see `modules/nixos/sops.nix`). So today:
- `.sops.yaml` still has the placeholder `age1PLACEHOLDER_blaney-pc`, and
- `secrets/blaney-pc.yaml` does not exist.

PR #80 expects `secrets/blaney-pc.yaml` to contain `wg-nm-private-key` and is gated behind
`blaneyWgVpn = false` until that's true.

## STRICT rules for this session (you are on blaney-pc)
- Work only on a branch named `blaney/...`. **Never** push to `main` or any non-`blaney/`
  branch. **Never** merge. lando (`landonreekstin`) merges the PR.
- Never commit the plaintext WireGuard private key or the SSH host private key.

## Input you must get from the operator (lando) — do not skip, do not improvise
Blaney's **existing** WireGuard private key for VPN peer `10.10.0.5`.
- The firewall (optiplex-fw) already has the matching **public** key for that peer, so you
  MUST reuse the existing private key. **Do NOT run `wg genkey`** — a new key would not
  match the firewall and would need a firewall change.
- lando retrieves it from optiplex-fw:
  `ssh fw` → `cat ~/openbsd-dotfiles/wireguard-clients/blaney*.conf` → the
  `[Interface] PrivateKey = ...` value (44-char base64 ending in `=`).
- Ask lando to paste it when you reach Step 5. Hold it only in a shell variable.

Also confirm you can push + open PRs from blaney-pc (`git push` works and `gh auth status`
is logged in). If not, stop and tell lando.

---

## Steps

### 1. Generate blaney-pc's SSH host key (the sops age source)
```bash
sudo ls -l /etc/ssh/ssh_host_ed25519_key 2>/dev/null
# If the private key is ABSENT, create the pair:
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C root@blaney-pc
# If the private key EXISTS but the .pub is missing, recreate the public half:
sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key | sudo tee /etc/ssh/ssh_host_ed25519_key.pub
```

### 2. Derive blaney-pc's age recipient (public age key)
```bash
AGE_PUB=$(sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age)
echo "$AGE_PUB"   # expect: age1...
```

### 3. Branch off main
```bash
cd ~/nixos-config
git fetch origin
git checkout -b blaney/wg-sops-setup origin/main
```
If the tree is owned by root from prior sudo use, fix ownership first
(`sudo chown -R "$USER":users ~/nixos-config`).

### 4. Put the real age key in `.sops.yaml`
```bash
sed -i "s|age1PLACEHOLDER_blaney-pc|$AGE_PUB|" .sops.yaml
grep -n "blaney-pc" .sops.yaml   # the &blaney-pc anchor must now show the real age1... key
```

### 5. Create + encrypt `secrets/blaney-pc.yaml`
```bash
# Paste Blaney's existing WG private key from lando (hidden input):
read -rs WG_PRIV; echo
printf 'wg-nm-private-key: %s\n' "$WG_PRIV" > secrets/blaney-pc.yaml
sops -e -i secrets/blaney-pc.yaml     # encrypts using the .sops.yaml rule -> [blaney-pc, lando]
unset WG_PRIV
grep -q '^sops:' secrets/blaney-pc.yaml && echo "encrypted OK" || { echo "NOT ENCRYPTED — abort"; exit 1; }
```

### 6. Verify blaney-pc itself can decrypt it
```bash
SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) \
  sops -d secrets/blaney-pc.yaml
# must print:  wg-nm-private-key: <the key>
```
If this fails, the age key in `.sops.yaml` doesn't match the host key — recheck Steps 2/4.

### 7. Eval-check (the secret is dormant on main, but must still evaluate)
```bash
NIXPKGS_ALLOW_UNFREE=1 nix eval --impure \
  ".#nixosConfigurations.blaney-pc.config.system.build.toplevel.drvPath"
```

### 8. Commit, push, open PR — then STOP
```bash
git add .sops.yaml secrets/blaney-pc.yaml
git commit -m "feat(blaney-pc): sops identity + WireGuard client key secret"
git push -u origin blaney/wg-sops-setup
gh pr create --base main --head blaney/wg-sops-setup \
  --title "feat(blaney-pc): sops identity + WireGuard client key secret" \
  --body "Establishes blaney-pc's sops identity (real age key in .sops.yaml) and adds encrypted secrets/blaney-pc.yaml with wg-nm-private-key. Unblocks PR #80 (WireGuard KDE client). No host config change; the secret is dormant until PR #80 flips blaneyWgVpn. Verified: sops -d decrypts on blaney-pc; blaney-pc evals."
```
Do **not** merge. Report the PR link to lando.

---

## What happens after this merges (lando / a follow-up — NOT this session)
1. Rebase PR #80 on main, set `blaneyWgVpn = true` in `hosts/blaney-pc/default.nix`,
   `rebuild` blaney-pc.
2. In the KDE network applet, toggle the **homelab-vpn** profile on; confirm the NAS
   (`192.168.1.76`) is reachable and `.lan` names resolve (nginx-gated). Firewall already
   has the `10.10.0.5` peer — no change needed.
3. Merge PR #80.

## Safety recap
- Only `.sops.yaml` and `secrets/blaney-pc.yaml` change here — no host config, no rebuild
  required to land.
- `secrets/blaney-pc.yaml` must show `sops:`/`ENC[` before committing.
- Plaintext WG key and the SSH host private key never get committed.
