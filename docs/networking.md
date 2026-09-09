<!-- ~/nixos-config/docs/networking.md -->
> **Read this when**: touching the firewall, VPN peers, port forwards, DNS/`.lan`
> resolution, NAS addressing, or anything that has to cross the Main LAN ↔ server
> subnet boundary. Summary and key addresses live in `CLAUDE.md`.

# OpenBSD Firewall (optiplex-fw)

The only non-NixOS host in the homelab. Works perfectly and is not managed by NixOS — it just needs to be understood when NixOS service changes also require firewall/VPN changes (new port forward, new WireGuard peer, etc.).

**Config files**: tracked in the private `github.com:landonreekstin/openbsd-dotfiles` repo, cloned at `~/openbsd-dotfiles/` on optiplex-fw. The live files on the box are always the source of truth.

## Network Topology

```
Internet
    │
    ▼
Spectrum Router (SAX2V1S)
WAN: 68.184.198.204  /  LAN: 192.168.1.1
    │
    ├── 192.168.1.x  (Main LAN)
    │   ├── gaming-pc       192.168.1.62
    │   └── optiplex-fw     192.168.1.189
    │         └─ re0 alias  192.168.1.76  (legacy NAS IP; rdr'd to 192.168.100.76)
    │
    ▼
┌──────────────────────────────────────────┐
│  OpenBSD Firewall (optiplex-fw)          │
│  Hardware: Dell Optiplex 3040 MT         │
│  OS: OpenBSD 7.9                         │
│  ext_if re0: 192.168.1.189 (Main LAN)   │
│           +  192.168.1.76/32 alias       │
│  int_if em0: 192.168.100.1 (Server LAN) │
└──────────────────────────────────────────┘
    │
    ├── 192.168.100.x  (Server LAN)
    │   ├── optiplex-nas    192.168.100.76
    │   └── mini-server     192.168.100.103
```

**optiplex-nas is behind the firewall** (moved off the Main LAN 2026-07-15). Its old
address `192.168.1.76` lives on as a `/32` alias on the firewall's `re0`, with pf
`rdr-to` rules forwarding the exposed services to `192.168.100.76` so LAN/VPN clients
that still know the NAS as `.76` keep working with no client changes. See
[NAS-behind-firewall specifics](#nas-behind-firewall-specifics) below.

## SSH Access

```bash
ssh lando@192.168.1.189   # direct
ssh fw                     # via ~/.ssh/config alias on gaming-pc
```

## Key PF Commands

```bash
doas pfctl -f /etc/pf.conf   # reload rules after editing
doas pfctl -sr                # show active rules
doas pfctl -ss                # show state table
doas pfctl -si                # statistics
```

## Adding a Port Forward

1. **Router**: add forward in mySpectrum app → 192.168.1.189
2. **optiplex-fw** `/etc/pf.conf`: add rdr-to rule, then `doas pfctl -f /etc/pf.conf`
3. Commit change to openbsd-dotfiles repo

## WireGuard VPN

- **Listen port**: 51822 (UDP) — forwarded directly by the Spectrum router to 192.168.1.189
- **VPN subnet**: 10.10.0.0/24 — server is 10.10.0.1
- **Server public key**: `Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=`
- **Server private key**: `/etc/wireguard/server_private.key` — NOT tracked in any repo
- **Interface config**: `/etc/hostname.wg0`

### Peers

| Name | VPN IP | Access | Notes |
|------|--------|--------|-------|
| Lando (gaming-pc) | 10.10.0.2 | Full | |
| Lando (Android) | 10.10.0.3 | Full | full tunnel (0.0.0.0/0) |
| Chris | 10.10.0.4 | Restricted | NAS only (192.168.1.76) |
| Blaney | 10.10.0.5 | Restricted | NAS only |
| Emily | 10.10.0.6 | Restricted | NAS only |
| Russell | 10.10.0.7 | Restricted | NAS only |
| Cmoore | 10.10.0.8 | Restricted | NAS only |
| Alex | 10.10.0.10 | Restricted | NAS only |
| Lando (gaming-pc wg-nas) | 10.10.0.11 | NAS Samba only | Dedicated LAN tunnel for encrypted SMB; allowed-ips 192.168.100.76/32. See `nasViaLanWg` in `hosts/gaming-pc/vars.nix`. |
| AJ | 10.10.0.13 | Restricted | NAS only |

Restricted peers can reach (all via the legacy 192.168.1.76 alias, rdr'd to the NAS at 192.168.100.76): Jellyfin (8096), Jellyseerr (5055), article2pod/reader (8100) on the NAS, and game-control dashboard (8080) + Vaultwarden (8222) on mini-server. Transmission is no longer exposed to restricted peers. All other traffic blocked via `<restricted_peers>` PF table.

## NAS-behind-firewall specifics

optiplex-nas is on the server subnet at **192.168.100.76**. Its NixOS static IP is set
in `hosts/optiplex-nas/networking.nix` (`192.168.100.76` / gw `192.168.100.1`).

**Legacy `192.168.1.76` alias + rdr** (in `/etc/pf.conf` on optiplex-fw): the firewall
holds `192.168.1.76/32` as an alias on `re0` and redirects to the NAS:
- **From the Main LAN (`re0`)**: TCP `80` (nginx reverse proxy — serves all the
  `*.lan` domains by Host header), `8096` (Jellyfin), `5055` (Jellyseerr), `5000`
  (nix binary cache), and `53` (DNS, tcp+udp) → `192.168.100.76`.
- **From WireGuard (`wg0`)**: full peers get the same `53` (DNS) and `80` (reverse
  proxy → `*.lan`) as the LAN, plus `445`/`139` (Samba), `9091` (Transmission), and the
  service ports; `8100` (article2pod) is redirected for all peers. Restricted peers are
  then filtered by the `<restricted_peers>` allow-list (they use `1.1.1.1` for DNS and
  reach services by direct IP, so they don't need 53/80).
- **SSH to the NAS is NOT forwarded on `.76`** — port 22 to `192.168.1.76` hits the
  firewall itself. Reach the NAS via jump host: `ssh -J lando@192.168.1.189 lando@192.168.100.76`
  (or over the wg-nas tunnel from gaming-pc).

**VPN peer addressing (which NAS address a client should use)** — the legacy `.76`
redirect only helps a peer if that peer's WireGuard **`AllowedIPs`** actually routes
`192.168.1.76` into the tunnel:
- **Restricted peers** (Chris, Blaney, …) are generated with `AllowedIPs = 192.168.1.76/32`
  (see `add-vpn-client.sh`), so they route only `.76` and reach NAS services via the
  legacy alias + rdr. Correct address for them: **`192.168.1.76`**.
- **Full peers** whose tunnel routes the **server subnet** (`192.168.100.0/24`) but *not*
  the old Main LAN (`192.168.1.0/24`) — e.g. Lando's phone — must use the NAS's real
  address **`192.168.100.76`** (the `.76` alias won't route for them). To make the legacy
  `.76` work for such a peer instead, add `192.168.1.0/24` to that peer's client-side
  `AllowedIPs`. gaming-pc sidesteps this entirely via the dedicated `wg-nas` tunnel.

**DNS**: the NAS runs Unbound (`homelab.dns.enable`) as the LAN resolver — a split-horizon
setup that serves the `.lan` zone locally and forwards everything else to Cloudflare/Quad9
over DoT. The `.76`→NAS port-53 rdr routes queries aimed at the legacy IP to it.

**The Spectrum router does NOT hand out `192.168.1.76` as the DHCP DNS server** — it points
DHCP clients at itself (`192.168.1.1`), which knows nothing about `.lan`. NixOS hosts resolve
`.lan` only because their resolver is hardcoded to `192.168.1.76` in config (`localDns.server`
/ `networking.nameservers`); `mini-server` (server subnet) points directly at `192.168.100.76`.
Plain DHCP devices (phones, guests, IoT) therefore **cannot resolve `.lan` out of the box**.
The fix used is **per-device static DNS = `192.168.1.76` with NO public secondary** (a public
DNS2 like `8.8.8.8` poisons `.lan`, since clients race the two resolvers and accept the public
NXDOMAIN). A LAN-wide fix (router DHCP → `.76`) was rejected: it makes the NAS a single point
of failure for all internet DNS and routes every device's lookups through the NAS's Mullvad
full-tunnel exit.

**Mullvad return-route gotcha** (`hosts/optiplex-nas/networking.nix`): the NAS runs Mullvad
as a full-tunnel VPN, whose policy routing sends any subnet **not in the main routing
table** into the tunnel. Replies to Main-LAN clients (`192.168.1.0/24`) and WireGuard
peers (`10.10.0.0/24`) would vanish into Mullvad, so explicit main-table routes send
that return traffic back through the firewall:
```nix
networking.interfaces.enp0s31f6.ipv4.routes = [
  { address = "192.168.1.0"; prefixLength = 24; via = "192.168.100.1"; }
  { address = "10.10.0.0";   prefixLength = 24; via = "192.168.100.1"; }
];
```
Without these, DNS/Jellyfin/Samba/nix-cache all break for anything not on the server
subnet — the SYN arrives at the NAS but the reply disappears into the VPN.

**gaming-pc Samba over wg-nas**: gaming-pc mounts the NAS Samba share (`/mnt/nas`) over a
dedicated LAN WireGuard tunnel (`wg-nas`, peer `10.10.0.11`, allowed-ips
`192.168.100.76/32`) so SMB is never in cleartext on the LAN. Gated by `nasViaLanWg` in
`hosts/gaming-pc/vars.nix` (tunnel in `hosts/gaming-pc/networking.nix`); the private key is in `secrets/gaming-pc.yaml` as
`wg-nas-private-key`. The `rebuild` cache-push (`modules/nixos/common/commands.nix`)
pushes to the NAS at `192.168.100.76` (reachable via this tunnel / directly from the
server subnet).

### Adding a New Peer

Run `~/openbsd-dotfiles/scripts/add-vpn-client.sh <name> [--jellyfin]` from optiplex-fw. The script:
- Auto-detects next available VPN IP
- Generates keypair, adds to live wg0 and hostname.wg0, updates pf.conf restricted_peers table
- Optionally creates a Jellyfin user
- Generates a QR code (if `qrencode` installed) and saves client config to `~/openbsd-dotfiles/wireguard-clients/`

After running: commit the updated configs in openbsd-dotfiles, then add the new row to the Peers table above.

### WireGuard Management Commands

```bash
ssh fw
doas wg show              # status and peer handshake times
doas wg show wg0 dump     # detailed peer info
```

### Hairpin NAT Limitation

The Spectrum router does not support hairpin NAT. Gaming-pc works around this with a static route: `68.184.198.204/32 via 192.168.1.189` (configured in `hosts/gaming-pc/networking.nix` via `networking.networkmanager.dispatcherScripts`). OpenBSD has matching rdr-to rules for this traffic.

## Wake-on-LAN

```bash
ssh fw
wake-gaming    # wakes gaming-pc (10:ff:e0:36:db:4b on 192.168.1.255)
wake-optiplex  # wakes optiplex (e4:b9:7a:ed:67:8c on 192.168.100.255)
```

Aliases are in `~/.kshrc` on optiplex-fw. Requires `customConfig.networking.wakeOnLan` enabled in each NixOS host config.

