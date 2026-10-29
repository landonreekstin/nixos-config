# Fix GitHub not working while the VPN is on

**What's wrong / what's wanted:** when Blaney has the homelab VPN (**homelab-vpn** in the
network applet) switched on, blaney-pc can't fetch from GitHub. With it off, GitHub works.
Find out why on this machine and fix it so both work at the same time.

**Important — you need GitHub yourself.** Do every push/PR step with the VPN **off**
(`nmcli connection down homelab-vpn`), and turn it back on only to reproduce/verify.
Leave it in the state Blaney had it when you finish.

**Where:**
- `hosts/blaney-pc/networking.nix` — `customConfig.services.wireguard.nmClient` (the VPN
  profile) and `customConfig.services.remoteAdmin` (lando's SSH over the VPN)
- `modules/nixos/services/wireguard-nm-client.nix` — renders the NetworkManager profile
- `modules/nixos/common/networking.nix` — DNS handling (blaney-pc uses plain DHCP DNS:
  `networking.nameservers = []`, NM `dns = "default"`, no systemd-resolved)

## What lando already ruled out (2026-10-29) — do not "fix" these

- **The repo profile is a split tunnel.** `allowed-ips` is only
  `192.168.1.76/32;10.10.0.2/32;10.10.0.11/32;`, no gateway, no DNS, IPv6 disabled on the
  tunnel. GitHub traffic *should* never enter it.
- **The firewall (optiplex-fw) is not blocking GitHub.** While Blaney was connected, the
  rule that drops restricted peers' non-NAS traffic had only 25 packets ever, the pf block
  log had nothing from `10.10.0.5`, and a capture saw no non-NAS traffic from him. So
  GitHub traffic is not going into the tunnel — the failure is local to blaney-pc.
- Do **not** add `0.0.0.0/0` or DNS to the profile, and do not touch the firewall.

## Step 1 — reproduce and diagnose (VPN on)

Get the exact error first (`git -C ~/nixos-config fetch -v` and, if the remote is SSH,
`ssh -T git@github.com`). Then compare these with the VPN **on** and **off**:

```bash
ip -4 addr; ip -4 route; ip rule
cat /etc/resolv.conf
nmcli -t connection show --active
nmcli connection show homelab-vpn | grep -E 'allowed-ips|ipv4\.|ipv6\.|wireguard\.'
ls /etc/NetworkManager/system-connections/      # any old hand-made VPN profile left over?
getent hosts github.com
curl -sI https://github.com | head -1
ip route get "$(getent hosts github.com | awk '{print $1; exit}')"
```

Suspects, in rough order:
1. **Address clash.** Blaney's ISP is AT&T, whose routers hand out `192.168.1.x`. If
   blaney-pc's own LAN address (or its router/DNS) is `192.168.1.76`, the NAS route
   collides with it. Look at `ip -4 addr` and the DHCP gateway/DNS.
2. **A stale or duplicate VPN profile.** `ensureProfiles` never deletes other NM profiles;
   blaney-pc had a hand-made tunnel before August. Check that the active profile is the
   declarative one with the `allowed-ips` above and that no other profile routes `0.0.0.0/0`.
3. **DNS changes** when the tunnel comes up (`resolv.conf` differs on vs off).
4. Anything else the on/off comparison shows. Write down which case it was.

## Step 2 — fix

Fix it in the repo (not by hand-editing NM files), `rebuild`, and verify. If the cause is
a leftover hand-made profile, removing it is fine, but also stop it coming back if you can.

## Also check while you're here: lando's SSH doesn't reach this PC

`ssh blaney` from lando's gaming-pc (source `10.10.0.11`) times out. The firewall passes it
(a state is created) but blaney-pc never answers on port 22. Check, with the VPN on:
`systemctl status sshd`, that the `lando` account exists, that `nft list ruleset` /
`iptables -S` opens 22 on `wg-homelab`, and that the live profile's `allowed-ips` include
`10.10.0.2` and `10.10.0.11` (if the live profile is older than the repo, that alone
explains it — a `rebuild` from current `main` should fix it). Report what you found in the PR.

**Done when:** with homelab-vpn on, `git -C ~/nixos-config fetch` succeeds **and**
`curl -sI http://192.168.1.76:8096/ | head -1` still answers (the NAS still works over the
VPN). Put the on/off diagnosis output and the cause in the PR description.

**Notes:**
- If you can't reproduce it (GitHub works with the VPN on), say so in the PR with the
  diagnosis output and make no changes beyond the SSH check.
- Any change he'd notice needs a line in `hosts/blaney-pc/release-notes.nix`
  (e.g. "GitHub works now even with the VPN on").
