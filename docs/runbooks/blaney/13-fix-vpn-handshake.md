# Fix the homelab VPN not connecting

**What's wrong / what's wanted:** **homelab-vpn** (in the network applet) switches on but
never connects. blaney-pc keeps sending handshakes and never gets an answer, so
`sudo wg show wg-homelab` shows a `latest handshake` that keeps getting older. Find out
where the firewall's replies are being lost and get the VPN connecting again.

**Where:**
- `hosts/blaney-pc/networking.nix` — `customConfig.services.wireguard.nmClient` (the VPN
  profile: endpoint `68.184.198.204:51822`, `persistentKeepalive = 25`)
- `modules/nixos/services/wireguard-nm-client.nix` — renders the NetworkManager profile

## What lando already ruled out (2026-10-30, ~20:47 CDT) — do not "fix" these

Checked on optiplex-fw (the homelab end) while Blaney was trying to connect:
- `wg0` is up on 51822 and Blaney's peer (10.10.0.5, key `sG7Al…`) is configured. Other
  peers were handshaking normally.
- The homelab's public IP is still **68.184.198.204**, the same as the endpoint in the repo.
- The pf rule that lets WireGuard in matches, and Blaney's flow has a pf state.
- **The firewall answers every handshake within a millisecond.** A capture showed:
  ```
  20:47:25.962 <blaney-public-ip>.40027 > 192.168.1.189.51822: [wg] initiation from 0xd0da59d2
  20:47:25.963 192.168.1.189.51822 > <blaney-public-ip>.40027: [wg] response   to   0xd0da59d2
  ```
  This repeated about every 5 seconds. So the replies leave the homelab firewall and get
  lost after that, either at lando's router on the way out or at Blaney's router/ISP
  (AT&T) on the way in.

So do **not** change the endpoint, the keys, or `allowed-ips`, and do not touch the firewall.

## Step 1 — do the replies reach blaney-pc? (VPN on)

```bash
nmcli connection up homelab-vpn
sudo wg show wg-homelab                       # note the endpoint, source (listening) port, handshake
sudo timeout 30 tcpdump -ni any udp port 51822
ip -4 addr; ip -4 route
nmcli -t connection show --active
```

In the tcpdump output, look for packets **from** `68.184.198.204.51822`:
- **You see them arriving, but there's still no handshake:** the problem is on blaney-pc.
  Check a local firewall (`nft list ruleset`), the key, and the duplicate/stale NM
  profiles from runbook 12.
- **You only see your own outgoing initiations:** the replies are lost before they reach
  this PC. Go to Step 2.

## Step 2 — get a new path through the routers

1. Turn the VPN off and on again (`nmcli connection down homelab-vpn; nmcli connection up
   homelab-vpn`). Check whether the source port changed (`sudo wg show wg-homelab`
   `listening port`) and whether a handshake now completes.
2. If it still fails, ask Blaney to restart his home router (wait until the internet is
   back), then try again.
3. If it still fails after his router restart, it is most likely lando's router. Stop
   and write that in the PR, with the times and the source port you tried, so lando can
   check with his own capture.

If restarting fixes it, also check whether it stays connected: leave it on 10+ minutes
and re-check `latest handshake`. If it keeps dropping, a stuck NAT mapping on the AT&T
router is the likely cause. A repo-side mitigation to consider is having the NM profile
use a new random source port each time it connects (if it currently pins one). Explain
your choice in the PR.

**Done when:** with homelab-vpn on, `sudo wg show wg-homelab` shows a handshake less than
2 minutes old **and** `curl -sI http://192.168.1.76:8096/ | head -1` answers (the NAS
over the VPN). Put the tcpdump output, the source ports you tried, and what fixed it in
the PR description. If nothing in the repo needed changing, still open a PR that just
deletes this runbook, with the findings in the description.

**Notes:**
- You need GitHub yourself, so do the push/PR with the VPN **off** if runbook 12 isn't
  fixed yet. Leave the VPN in the state Blaney had it.
- Any change he'd notice needs a line in `hosts/blaney-pc/release-notes.nix`
  (e.g. "The homelab VPN connects again").
