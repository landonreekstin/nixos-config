# Host an R62D game that Lando can join

**What's wrong / what's wanted:** Blaney wants to host R62D on blaney-pc while he's on the
homelab VPN, so Lando can join from his gaming PC at home at **`http://10.10.0.5:6262`**.
Everything on Lando's side is ready. It fails because **blaney-pc's VPN never connects**,
so nothing reaches 10.10.0.5. Get the VPN connecting, then make sure the game is open to
the network.

**Where:**
- `hosts/blaney-pc/networking.nix`: `customConfig.services.wireguard.nmClient` (the
  `homelab-vpn` NetworkManager profile, `wg-homelab`, 10.10.0.5, endpoint
  `68.184.198.204:51822`, allowed-ips `192.168.1.76/32;10.10.0.2/32;10.10.0.11/32;`)
- `modules/nixos/services/wireguard-nm-client.nix`: renders that profile
- `hosts/blaney-pc/apps.nix`: `programs.r62d = { enable = true; openFirewall = true; }`
  (opens TCP 6262 on blaney-pc)
- `~/projects/r62d/server/server.js`: blaney-pc runs his project folder (`localApps`),
  not the pin. `BIND` defaults to `0.0.0.0`; PLAY sets `127.0.0.1` (this computer only)
  and HOST/OPEN TO LAN calls `openTo('0.0.0.0')`.

## What Lando already checked (2026-11-03, ~21:30 CST): do not "fix" these

From gaming-pc and optiplex-fw:
- **Firewall: done.** optiplex-fw has
  `pass in quick on wg0 proto tcp from { 10.10.0.2, 10.10.0.11 } to 10.10.0.5 port { 22, $r62d_port }`
  loaded, ahead of the restricted-peers block. Only Lando's two gaming-pc peers may join.
  That's intended, so don't widen it or `allowed-ips`.
- **Lando's side: fine.** gaming-pc's `wg-nas` (10.10.0.11) handshakes every minute and
  routes 10.10.0.0/24.
- **The homelab public IP is still 68.184.198.204**, the same as the repo endpoint.
  Other remote peers handshake normally, so the router forwards 51822.
- **Blaney's peer (key `sG7Al…`) last handshook ~24 h earlier** (from `66.124.124.73`).
  Over ~2 minutes of capture on optiplex-fw's re0, **one** packet arrived from him and then
  nothing. This is **not** runbook 13's symptom: there, the firewall answered every
  initiation and the replies got lost. This time his initiations aren't reaching the
  firewall at all. A tunnel that is on and failing would retry every ~5 s, so expect
  the cause on blaney-pc or his network: VPN off, dropping right after it comes up, or
  blocked outbound.
- **Ping is not a test.** pf passes only TCP 22/6262 to 10.10.0.5.

Do not change the endpoint, the keys, `allowed-ips`, or anything on the firewall.

## Step 1: is the VPN really on, and is it sending? (Claude, can run unattended)

```bash
nmcli -t connection show --active              # is homelab-vpn listed?
nmcli connection up homelab-vpn                # if not, bring it up and read any error
sudo wg show wg-homelab                        # handshake? are "sent" bytes rising?
sudo timeout 30 tcpdump -ni any udp port 51822
journalctl -b -u NetworkManager | grep -i homelab | tail -30
ip -4 addr; ip -4 route
```

- **homelab-vpn missing or fails to come up:** the profile or its secret is broken
  (sops key, a duplicate/stale NM profile; see runbook 12). Fix it in the repo and rebuild.
- **Initiations leave every ~5 s and nothing comes back:** follow runbook 13, Step 2
  (re-up for a new source port, then Blaney restarts his router). If even that fails,
  try a phone hotspot to tell his network apart from blaney-pc (Step 2 below).
- **It comes up, then drops within a minute or two:** look for what takes it down in the
  NetworkManager log (Wi-Fi reconnects, autoconnect fights between two profiles).
- **Handshake completes:** go to Step 3.

If runbook 13 is still in the menu and this turns out to be the same problem, fix it once
and say in the PR that it covers both.

## Step 2: phone hotspot test (needs Blaney there)

Only if Step 1 shows initiations leaving with no handshake. Blaney connects the PC to his
phone's hotspot, Claude turns homelab-vpn off and on and checks `sudo wg show wg-homelab`.
If the hotspot connects, his home router/ISP is blocking or eating the traffic. Write
that in the PR with times and source ports. Don't change config for it.

## Step 3: game open to the network

1. Start R62D the way Blaney does (the `r62d` menu entry), and have him pick **HOST** /
   OPEN TO LAN, **not PLAY**. PLAY only listens on 127.0.0.1.
2. Check: `ss -ltnp | grep 6262` shows `0.0.0.0:6262` (or `*:6262`), not `127.0.0.1:6262`.
   `nft list ruleset | grep 6262` shows the port open (from `openFirewall`).
3. Tell Blaney in plain words: Lando can't use JOIN to find his game, because JOIN's
   search (UDP 6264) doesn't cross the VPN. Lando types `http://10.10.0.5:6262` instead.
   That's expected, not a bug.

If the menu or lobby makes HOST hard to find, or shows an address Lando can't use, that's
a game change in `~/projects/r62d` (his repo, his `main`, his project `CLAUDE.md`). Ask
Blaney how he wants it to look before changing it.

**Done when:** with homelab-vpn on, `sudo wg show wg-homelab` shows a handshake under
2 minutes old **and still does 10 minutes later**, `curl -sI http://192.168.1.76:8096/ | head -1`
answers (the NAS over the VPN), and with HOST picked `ss -ltn` shows R62D on `0.0.0.0:6262`.
Then Lando opening `http://10.10.0.5:6262` from gaming-pc is the in-person check, so list
it under "Needs checking in person" in the PR. Put the tcpdump output, source ports and
what fixed it in the PR description. If nothing in the repo needed changing, still open
a PR: add a short "if Blaney's VPN won't connect" note with the cause and fix under
"R62D (port 6262)" in `docs/networking.md`.

**Notes:**
- You need GitHub yourself. If runbook 12 isn't fixed, push and open the PR with the VPN
  **off**, then leave it the way Blaney had it.
- Any change he'd notice needs a line in `hosts/blaney-pc/release-notes.nix`
  (e.g. "The homelab VPN connects again, so Lando can join your R62D games").
