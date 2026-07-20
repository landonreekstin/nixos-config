# Runbook: blaney-pc sops setup (unblocks the WireGuard client, PR #80)

**Why:** blaney-pc has no sops identity (it runs with `services.ssh.enable = false`, so NixOS
never generated `/etc/ssh/ssh_host_ed25519_key`; sops derives every host's age key from that
— see `modules/nixos/sops.nix`). So `.sops.yaml` still has `age1PLACEHOLDER_blaney-pc` and
`secrets/blaney-pc.yaml` doesn't exist. PR #80 (`feat/wg-clients-lan-access`) needs that
secret (`wg-nm-private-key`) and stays gated behind `blaneyWgVpn = false` until it exists.

**Connectivity reality:** blaney-pc is **remote** — it only reaches the homelab (firewall,
NAS) *through* the VPN we're setting up, and it does **not** have the firewall's SSH key. It
*can* reach GitHub over the plain internet. So the work is split so blaney-pc never needs the
LAN and never handles the WireGuard private key.

---

## Part A — on blaney-pc (no LAN/VPN needed; nothing secret leaves the box)
Run these on blaney-pc, then send lando the printed `age1…` line (it's a **public** key —
safe to send over any channel):

```bash
# 1. Create the SSH host key if absent (this is the sops age source):
sudo ls -l /etc/ssh/ssh_host_ed25519_key 2>/dev/null \
  || sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C root@blaney-pc
# (if the private key exists but .pub is missing:
#   sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key | sudo tee /etc/ssh/ssh_host_ed25519_key.pub )

# 2. Print blaney-pc's age PUBLIC key — send this to lando:
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

That is blaney-pc's entire part. Do **not** generate any WireGuard key here.

---

## Part B — on lando's side (gaming-pc; has firewall access + controls secrets)
Inputs: blaney-pc's `age1…` public key (from Part A).

1. **Get Blaney's existing WG private key** (do NOT generate a new one — the firewall
   already has the matching public key for peer `10.10.0.5`, and reusing it means no
   firewall change):
   ```bash
   ssh fw
   cat ~/openbsd-dotfiles/wireguard-clients/blaney*.conf   # the [Interface] PrivateKey = ...
   ```

2. **Branch, wire up sops, encrypt, PR** (a feat branch off main; secret stays dormant on
   main because nothing references it until PR #80):
   ```bash
   cd ~/nixos-config && git checkout main && git pull
   git checkout -b feat/blaney-sops
   sed -i "s|age1PLACEHOLDER_blaney-pc|<BLANEY_AGE_PUB>|" .sops.yaml
   printf 'wg-nm-private-key: %s\n' "<BLANEY_WG_PRIVATE_KEY>" > secrets/blaney-pc.yaml
   sops -e -i secrets/blaney-pc.yaml          # encrypts to [blaney-pc, lando]
   grep -q '^sops:' secrets/blaney-pc.yaml && echo encrypted
   NIXPKGS_ALLOW_UNFREE=1 nix eval --impure ".#nixosConfigurations.blaney-pc.config.system.build.toplevel.drvPath"
   git add .sops.yaml secrets/blaney-pc.yaml
   git commit -m "feat(blaney-pc): sops identity + WireGuard client key secret"
   git push -u origin feat/blaney-sops
   gh pr create --base main --title "feat(blaney-pc): sops identity + WG client key secret" --body "..."
   ```
   Merge when ready. (Encryption needs only blaney-pc's *public* age key; the WG private key
   never leaves gaming-pc except as ciphertext in the committed secret.)

---

## Part C — after the sops PR merges (brings the VPN up)
1. On blaney-pc: `sync` over the internet to pull the merged secret.
2. Roll out PR #80: rebase it on main, set `blaneyWgVpn = true`, `rebuild` blaney-pc.
3. In the KDE network applet, toggle **homelab-vpn** on; confirm the NAS (`192.168.1.76`) is
   reachable and `.lan` resolves. Firewall already has the `10.10.0.5` peer — no change.
4. Merge PR #80.

## Notes
- The sops PR (Part B) touches only `.sops.yaml` + `secrets/blaney-pc.yaml` — no host config,
  evals clean on main, secret dormant until PR #80.
- `secrets/blaney-pc.yaml` must show `sops:`/`ENC[` before committing.
- The SSH host private key and the plaintext WG key are never committed.
