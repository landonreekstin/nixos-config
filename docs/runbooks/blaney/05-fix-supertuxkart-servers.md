# SuperTuxKart can't connect to any online servers

**What's wrong / what's wanted:** SuperTuxKart has not been able to reach online servers for a
long time. Blaney reports the same failure on his Windows machine, which points at his network
or at a per-machine game setting rather than at anything NixOS-specific. Work out what is
actually broken and fix what can be fixed.

**Be honest about the outcome.** The plausible causes include one that genuinely cannot be fixed
from this machine (his router's NAT behaviour). If that is what it turns out to be, say so
plainly, tell Blaney what he'd have to change on his router, and do not invent a NixOS change to
look productive.

**Where:**
- `modules/nixos/profiles/gaming.nix` (~line 79) — `networking.firewall.allowedUDPPorts = [ 2757 2759 ]`
- `~/.config/supertuxkart/config-0.10/config.xml` — the per-user game config (not in the repo)

## What is already ruled out — do not spend time on these

Checked on 2026-10-04 from outside Blaney's network:

- **The STK master server is up.** `https://online.supertuxkart.net/api/v2/server/get-all`
  returns HTTP 200 and a populated server list.
- **The protocol version matches.** Listed servers advertise `version="6"`, and STK's
  `data/stk_config.xml` declares `<server-version min="6" max="6"/>` in both 1.4 and 1.5. So
  this is *not* a client-too-new problem and the servers will not be filtered out of the list.
- **The game is current.** This host builds `supertuxkart` 1.5, the latest release.
- **The firewall ports are already open.** UDP 2757/2759 are opened by the gaming profile, which
  this host enables. Those matter for *hosting* and LAN discovery; joining works outbound via
  conntrack, so adding more ports is not the fix.
- **Four of STK's five default STUN servers answer.** `stunv4.linuxreviews.org`,
  `stunv4.7/8.supertuxkart.net` and `stun.supertuxkart.net` all respond to a STUN binding
  request. Only `stun.stunprotocol.org` is dead (NXDOMAIN — it shut down years ago), and that
  costs a timeout, not the feature.

## Step 1 — pin down the symptom exactly. This splits the whole problem.

Launch the game and ask Blaney to watch with you. There are three different failures and they
have nothing to do with each other:

| What he sees | Meaning | Go to |
|---|---|---|
| The Online menu is greyed out / refuses to open | internet access never granted in-game | step 2 |
| Online opens but the server list is **empty** | can't reach the master server | step 3 |
| Server list **populates**, joining hangs then times out | UDP punch-through failing | step 4 |

Get the game's own log while reproducing — it names the failing stage directly:

```bash
supertuxkart --log=1 2>&1 | tee /tmp/stk.log
grep -iE "stun|server|connect|error|warn|internet" /tmp/stk.log | tail -40
```

## Step 2 — the in-game internet permission (check this first regardless)

STK asks once, on first launch, whether it may use the internet. If that was declined or never
answered, every online feature is dead and it looks exactly like a network fault. This is per
machine, which is consistent with it being broken on his Windows box too.

```bash
grep -n enable_internet ~/.config/supertuxkart/config-0.10/config.xml
```

`enable_internet` values: **`0` = never asked, `1` = allowed, `2` = refused.** Anything other
than `1` is the bug. Fix it in the game's own UI — *Options → User Interface → Allow STK to
connect to the internet* — rather than by editing the XML, so the game doesn't rewrite it from
memory on exit. Then relaunch and re-check step 1.

Also worth confirming while you are in there: the config directory is
`~/.config/supertuxkart/config-0.10/`. If that path does not exist, the game has never
completed a first run as this user, which is itself the answer.

## Step 3 — empty server list: can this machine reach the master server?

```bash
getent hosts online.supertuxkart.net
curl -s -o /dev/null -w "http=%{http_code} ip=%{remote_ip} t=%{time_total}\n" \
  --max-time 20 "https://online.supertuxkart.net/api/v2/server/get-all"
curl -s --max-time 20 "https://online.supertuxkart.net/api/v2/server/get-all" | head -c 400
```

Expect `http=200` and XML beginning `<get-all success="yes"`. If DNS fails or the request hangs,
the problem is his DNS/ISP, not the game — test a different resolver (`dig @1.1.1.1
online.supertuxkart.net`) and check whether his router is doing DNS filtering.

If the API answers fine here but the in-game list is still empty, the game is not asking — go
back to step 2, and check whether STK is being blocked from making outbound HTTPS at all.

## Step 4 — list loads but joining times out: NAT mapping

This is the most likely cause of a long-standing, cross-platform failure. STK learns its own
public address via STUN, hands that to the server, and the server punches back. That only works
if the router gives the machine the **same public port for every destination** (an
endpoint-independent, "cone" NAT). A **symmetric** NAT hands out a fresh port per destination,
so the address STK advertised is already stale by the time the server replies — the server list
loads fine (that is plain HTTPS) and every join times out.

Run this. It reuses **one** local socket across several STUN servers, which is what makes the
answer meaningful — a naive test that opens a new socket per server always shows different ports
and proves nothing:

```bash
cat > /tmp/stk-nat.py <<'PY'
import socket, struct, os, sys
MAGIC = 0x2112A442
SERVERS = [("stunv4.linuxreviews.org", 3478), ("stunv4.7.supertuxkart.net", 3478),
           ("stunv4.8.supertuxkart.net", 3478), ("stun.supertuxkart.net", 3478)]

def binding(sock, host, port, timeout=3.0):
    tid = os.urandom(12)
    try:
        dest = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_DGRAM)[0][4]
    except Exception:
        return None, "dns-fail"
    sock.settimeout(timeout)
    try:
        sock.sendto(struct.pack(">HHI12s", 0x0001, 0, MAGIC, tid), dest)
        while True:
            data, _ = sock.recvfrom(2048)
            if len(data) >= 20 and data[8:20] == tid:
                break
    except socket.timeout:
        return None, "timeout"
    except Exception as e:
        return None, "error:" + e.__class__.__name__
    mt, ln = struct.unpack(">HH", data[:4])
    if mt != 0x0101:
        return None, "type-0x%04x" % mt
    i, end = 20, 20 + ln
    while i + 4 <= end:
        at, al = struct.unpack(">HH", data[i:i+4])
        v = data[i+4:i+4+al]
        i += 4 + ((al + 3) // 4) * 4
        if at in (0x0020, 0x0001) and len(v) >= 8:
            p = struct.unpack(">H", v[2:4])[0]
            a = v[4:8]
            if at == 0x0020:
                p ^= MAGIC >> 16
                a = bytes(x ^ y for x, y in zip(a, struct.pack(">I", MAGIC)))
            return (socket.inet_ntoa(a), p), "ok"
    return None, "no-mapped-address"

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("0.0.0.0", 0))
print("local source port: %d\n" % s.getsockname()[1])
seen = []
for host, port in SERVERS:
    mapped, status = binding(s, host, port)
    if mapped:
        print("  %-30s -> %s:%d" % (host, mapped[0], mapped[1]))
        seen.append(mapped)
    else:
        print("  %-30s -- %s" % (host, status))
s.close()
print()
if len(seen) < 2:
    print("INCONCLUSIVE: fewer than two STUN servers answered.")
    print("If ALL failed, outbound UDP/3478 is blocked -- STK can never learn its")
    print("public address, and that alone explains the failure.")
    sys.exit(2)
ips = {m[0] for m in seen}
ports = {m[1] for m in seen}
print("public IP(s):   " + ", ".join(sorted(ips)))
print("public port(s): " + ", ".join(str(p) for p in sorted(ports)))
print()
if len(ips) == 1 and len(ports) == 1:
    print("VERDICT: endpoint-independent (cone) NAT -- STK punch-through CAN work.")
    print("The NAT mapping is NOT the problem; look at steps 2 and 3.")
    sys.exit(0)
print("VERDICT: SYMMETRIC NAT (a different public port per destination).")
print("This breaks SuperTuxKart WAN joining and is NOT fixable on this machine.")
sys.exit(1)
PY
nix shell nixpkgs#python3 --command python3 /tmp/stk-nat.py
```

Reading the result:

- **Cone NAT** — the mapping is fine. The cause is elsewhere; re-read steps 2 and 3, and check
  whether his router has a UDP flood/game filter or UPnP disabled in a way that matters.
- **Symmetric NAT** — this is the answer, and it is his router/ISP, not NixOS. It also explains
  the identical failure on Windows. What to tell him, in plain terms: his router is handing out a
  different "return address" to every server it talks to, so the game server's reply never finds
  its way back. Things that sometimes fix it, in order of how likely they are to help:
  1. Turn on UPnP / NAT-PMP in the router (lets the game ask for a stable port)
  2. Forward UDP 2757 and 2759 to this machine, which also lets him *host* a game
  3. If his ISP has him behind CGNAT (a WAN IP in `100.64.0.0/10` — check the router's status
     page), nothing on his side will fix it and he needs a public IP from the ISP
- **All STUN servers failed** — outbound UDP/3478 is blocked. Check whether anything local is
  doing it (`sudo iptables-save | grep -i 3478`, `systemctl status firewall`) before blaming the
  router; the NixOS firewall does not block outbound by default, so a local cause is unlikely.

## Step 5 — the escape hatch that always works

If the diagnosis is his NAT, Blaney and lando can still play together over the **homelab VPN**,
or on a private STK server. He already has a `homelab-vpn` NetworkManager profile in his network
applet (`hosts/blaney-pc/networking.nix`), though note it is a *restricted* peer routing only
`192.168.1.76/32` — so STK over it would need routing and a server that do not exist yet.

**Do not build that as part of this task.** Write up what would be needed (an STK server on
`mini-server`, which runs lando's other game servers, plus the VPN routing for it) and let lando
decide. This runbook's job is the diagnosis plus any fix that is actually on Blaney's side.

## Do this

1. Work steps 1 → 2 → 3/4 in order and **write down which branch you landed on**.
2. Apply whichever fix the diagnosis points to.
3. Verify the real thing: Blaney joins an online server and races a lap. Reaching the server list
   is not enough.
4. If a config change was needed: **branch** `blaney/fix-supertuxkart-online`, chown, `rebuild`,
   verify, commit, **open a PR**, and stop. Do not merge — lando does that.
5. If the cause is his router or a per-machine game setting, there is nothing to commit. Report
   the finding clearly, in plain language, with the specific router change he needs — and say
   explicitly that no PR is coming, rather than opening an empty one.

**Done when:** either Blaney has raced online, or he has been told in plain terms exactly what is
blocking it and what he would have to change to unblock it.

## Traps

- **Don't add firewall ports hoping it helps.** 2757/2759 are already open, and joining does not
  need inbound rules — conntrack covers the reply. Opening more ports changes nothing and hides
  the real cause.
- **Don't "upgrade" SuperTuxKart.** 1.5 is current and its protocol version matches what the
  listed servers advertise. An `unstable-override` here would be churn.
- **Don't edit the STUN server list in `config.xml` as a first move.** Four of the five defaults
  answer; a hand-edited list is per-user state that vanishes on reinstall and masks the diagnosis.
- **LAN vs WAN**: port 2757 is LAN discovery and 2759 is the game. "Local networking" working
  while "Internet" fails is the normal signature of a NAT problem and is useful evidence — note
  it rather than treating LAN success as the feature working.
- This host only reaches GitHub and `192.168.1.76` over the VPN — do not write steps that assume
  general homelab LAN access.
