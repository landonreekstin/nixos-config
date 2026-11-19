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
