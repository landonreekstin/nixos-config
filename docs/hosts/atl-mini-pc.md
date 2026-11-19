# atl-mini-pc

Mom's (Heather's) mini PC in Atlanta, on Wi-Fi. lando is there in person about once a year, and
until 2026-11 every fix reached it by mom running `update && rebuild`. It is now set up to be
**reached and repaired remotely**:

- **Always-on homelab VPN** as peer **10.10.0.19**, using a split tunnel that routes only lando's
  gaming-pc peers (10.10.0.2, 10.10.0.11). Her own traffic never touches it. It exists
  for SSH in. On optiplex-fw it is an ordinary restricted peer (Jellyfin, the public file drop),
  never Samba or the private services.
- **`ssh atl`** from gaming-pc puts you in her account (`heather`). That account is in wheel and has
  lando's keys (`modules/nixos/common/users-groups.nix`). sudo asks for her password.
- **A system-wide Wi-Fi profile** (`home-wifi-system`), so the machine is online after an
  unattended reboot. Her original profile keeps its password in KWallet (`3bf8f92`), which only
  unlocks when she logs in. Without this, a power cut means no network, no VPN and no updates
  until she logs in.
- **Weekly autoUpdate** (Mon 03:00, catches up on boot) pulls this repo from GitHub and
  rebuilds. Together with mom's `update && rebuild` it is **the lifeline**: if the tunnel breaks
  (new home WAN IP, server re-key), push the fix here and it arrives without the VPN.

The Wi-Fi SSID and password and the VPN private key are in `secrets/atl-mini-pc.yaml` (sops).
Everything except autoUpdate is gated by `atlSecrets` in `hosts/atl-mini-pc/networking.nix`.

## Status

| Step | State |
|---|---|
| optiplex-fw peer 10.10.0.19 + pf `tcp/22` from .2/.11 | **done 2026-11-19** (openbsd-dotfiles `b0cd073`, `97ff234`; key rotated the same day) |
| Nix config, gated by `atlSecrets = false` | **done 2026-11-19** |
| Host age key in `.sops.yaml` | waiting on mom |
| `secrets/atl-mini-pc.yaml` | waiting on the age key |
| Flip `atlSecrets`, mom runs `update && rebuild` | — |
| Verify | — |
| Offsite backup: rest-server here + mini-server job, gated | **done 2026-11-19**, see below |
| Offline kit (admin age key + restic password) | restic password in Vaultwarden + KeePassDX (phone) 2026-11-19; admin key into the kit by hand |
| Admin key one-off copy from asus-laptop | on the visit (below) |
| Flip `gameBackup.offsite.enable` on mini-server, first run, test restore | after Verify |

## Bootstrap (remote; no visit needed)

1. **Mom sends the host key.** It's a public key, so it's safe to text:
   `cat /etc/ssh/ssh_host_ed25519_key.pub`. Convert it with
   `echo '<that line>' | ssh-to-age` and replace `age1PLACEHOLDER_atl-mini-pc` in `.sops.yaml`.
2. **Create the secrets file** from `~/nixos-config` on gaming-pc. The password is typed at a
   prompt and goes straight into `sops`, so it never touches disk unencrypted or appears in a log:
   ```sh
   read -rp 'SSID: ' S; read -rsp 'Wi-Fi password: ' P; echo
   WG=$(ssh fw 'sed -n "s/^PrivateKey = //p" ~/openbsd-dotfiles/wireguard-clients/atl-mini-pc-client.conf')
   printf 'wg-homelab-key: %s\nwifi-env: |\n  WIFI_SSID=%s\n  WIFI_PSK=%s\n' "$WG" "$S" "$P" \
     | sops encrypt --filename-override secrets/atl-mini-pc.yaml /dev/stdin > secrets/atl-mini-pc.yaml
   unset S P WG; git add secrets/atl-mini-pc.yaml
   ```
   `wifi-env` is a systemd environment file: an SSID or password containing `"`, `\` or `$` needs
   quoting or escaping.
3. Set `atlSecrets = true`, then commit and push.
4. **Mom runs `update && rebuild`.** Nothing changes for her, apart from a second Wi-Fi entry.
5. **Verify:** run `ssh atl`, then `sudo wg show wg-homelab` should show a recent handshake. Then
   the real test: have her **reboot and not log in**, and `ssh atl` again.

## Offsite backup

Stage 0 of the Homelab 2.0 doc: *"a small restic backup of irreplaceable files to
atl-mini-pc"*. It is the doc's copy 2 of 3-2-1, built the way the doc says: **restic to a
rest-server in append-only mode, over WireGuard.**

| | |
|---|---|
| **Pushed by** | mini-server, nightly **04:45**, after its 04:00 NAS run (`gameBackup.offsite` in `modules/nixos/homelab/game-backup.nix`) |
| **Holds** | the same set as the NAS job: Home Assistant, Vaultwarden, game-server worlds, Forgejo's 03:30 dump |
| **Lands at** | `/var/lib/restic/mini-server` here, via `rest:http://10.10.0.19:8000/mini-server` |
| **Repo password** | `secrets/mini-server-offsite.yaml` (mini-server + admin key), **and the offline kit** |
| **Network** | mini-server → fw (passes the server subnet) → wg0 → here. `192.168.100.103/32` is in this host's AllowedIPs; port 8000 is open on `wg-homelab` only. No pf change was needed |

- **Append-only** means a compromised pusher can add snapshots and never delete one, so
  there is no `forget --prune` in the job (the server would refuse it and fail the unit).
  **Retention runs here**, by hand, occasionally: `ssh atl`, then
  `sudo restic -r /var/lib/restic/mini-server forget --keep-daily 14 --keep-monthly 12 --prune`
  and paste the password. The set is small and deduplicated, so growth is slow.
- **No auth on the server, on purpose.** WireGuard AllowedIPs are the access list. restic
  encrypts on mini-server, so nothing on this machine can read the data.
- **Check the disk on the visit:** `df -h /var`. Today's set is a few GB (the NAS repo for it
  is 6.5 GB).

### Turning it on (after Verify above)

1. Set `gameBackup.offsite.enable = true` in `hosts/mini-server/homelab.nix`, commit, and
   rebuild mini-server.
2. Run it once: `sudo systemctl start restic-backups-offsite` on mini-server, then read
   `journalctl -u restic-backups-offsite`. `initialize = true` creates the repo on the first
   run.
3. **Prove append-only:** from mini-server,
   `sudo restic -r rest:http://10.10.0.19:8000/mini-server --password-file /run/secrets/restic-offsite-password forget --keep-last 1 --prune`
   must **fail**.
4. **Test restore** (the doc's gate: a backup is only real once restored): restore
   `/var/lib/hass` from the latest snapshot into `/tmp/restore-test` on mini-server and
   diff it against the live directory.

### The offline kit

The doc: *"Back up the sops/age keys separately and offline (printed, or on a USB stick in a
safe place). Without them the encrypted secrets in nixos-config are gone."* It holds:

- **The admin age key**, `~/.config/sops/age/keys.txt` on **asus-laptop**. The file of the
  same name on gaming-pc is **gaming-pc's own host key**, not this one.
- **This repo's restic password.** It is in sops too, but recovering from losing the
  age key is the reason the kit exists, and that password would be locked inside the same
  loss. Written once to `~/offsite-restic-password.txt` on gaming-pc (mode 600) on
  2026-11-19, then saved the same day in **Vaultwarden** and in **KeePassDX on lando's phone**.
  The KeePassDX copy is the one that matters for recovery, since it doesn't depend on
  mini-server (Vaultwarden runs there and is in this very backup). The file was deleted
  the same day.

### The admin key offsite too (on the visit, from asus-laptop)

The admin key never leaves asus-laptop, which is usually off, so it gets a one-off copy here
instead of a nightly job. On her LAN, as `heather` over SFTP (her account already has your keys).
No sudo, no VPN, nothing to configure on her side:

```sh
# on asus-laptop, on her Wi-Fi
nix shell nixpkgs#restic
export RESTIC_REPOSITORY=sftp:heather@atl-mini-pc:.local/share/admin-key-backup
restic init                                   # NEW password: into the kit + Vaultwarden
restic backup ~/.config/sops/age/keys.txt
restic snapshots && restic dump latest /home/lando/.config/sops/age/keys.txt | age-keygen -y
#   ^ must print age1vnc3fnww3q9m9zau3ew8t0uzqfa9gp3w4za7y46rt5wu9xvrqggqcj8pfm (&lando)
```

This copy is not append-only (her account could delete it), which is fine for a one-off. The
kit is still the primary. Redo it only if the admin key ever changes.

## Still worth doing on the next visit

- **Make autoUpdate's git pull work unattended.** Her manual `update` already works, but
  autoUpdate is stricter: it runs as a system service, forces `-i ~/.ssh/id_ed25519` with
  `BatchMode=yes`, and has no agent and no passphrase prompt. The repo is public, so an HTTPS
  remote needs no key:
  `git -C ~/nixos-config remote set-url origin https://github.com/landonreekstin/nixos-config.git`.
  Check with `sudo systemctl start nixos-auto-update; journalctl -u nixos-auto-update`. This can
  also be done over `ssh atl`.
- In the BIOS, set **power on after AC loss**, if it has the setting.
- If her router is **WPA3-only**, `key-mgmt` must be `sae`, not `wpa-psk`.
