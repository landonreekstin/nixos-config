# Runbook: a read-only `public` drop for VPN users on optiplex-nas

**Status: built and verified on optiplex-nas, 2026-09-23** (PR #147). The HTTP drop is
live; the optional Samba section at the end was deliberately not built. What remains is
putting a payload in the drop — see "Afterwards".

**Why:** restricted VPN peers (Blaney, Chris, …) have no way to receive a file from the
homelab. The immediate need is ~15 GB of MW2 game files for
[mw2-iw4x-source.md](mw2-iw4x-source.md) reaching **blaney-pc, which is in another state**
— so a USB drive is not an option and everything has to cross the WAN. The general shape,
"somewhere to drop a file for a VPN user", keeps coming up.

## Serve it over HTTP, not SMB

The obvious instinct is a Samba share, since the NAS already serves `storage` and
`private` that way. For a remote user it is the wrong tool, and the reasons are worth
stating because they decide the whole design:

- **Port 80 is already open to restricted peers.** `/etc/pf.conf` passes them
  `{ 8096, 5055, 5000, 53, 80, $article2pod_port }` to the NAS. An HTTP drop needs **no
  firewall change at all**; SMB needs a new port opened on the edge.
- **HTTP resumes, CIFS does not.** This is ~15 GB over a WAN link to another state. A
  dropped SMB transfer starts over; `curl -C -` or a browser picks up where it left off.
- **CIFS is chatty and slow over latency.** The same transfer on the *LAN* only managed
  ~8 MB/s NAS→gaming-pc. Across the internet it would be considerably worse.
- **Read-only is inherent.** A `location` serving files answers GET. There is no write
  path to get wrong, no `read only = no` to forget, no guest account to scope.
- **Blaney can just click a link.** No mount, no credentials, no client-side Nix change —
  which matters because he is non-technical and remote.

Samba stays available as an *optional* convenience for LAN machines; see the last section.

## Why not just widen access to `storage`

Verified 2026-09-23, and any one of these alone is disqualifying:

1. **The share cannot be made read-only per-user.** One `storage` share, `read only = no`,
   `force user = lando`, behind a single `smb-credentials` secret. Handing that to a
   restricted peer grants full write to 2.8 TB. A client-side `ro` mount flag is **not**
   enforcement — the client chooses it and can choose otherwise.
2. **`pf` blocks SMB for them anyway.** 445/139 are deliberately absent from the
   allow-list above, followed by `block in quick on wg0 from <restricted_peers>`. Full
   peers *do* get 445/139 in the rule immediately above, which is what makes this easy to
   misread as already working.
3. **blaney-pc has no sops identity**, so it cannot receive `smb-credentials` at all.
   `.sops.yaml` still carries `age1PLACEHOLDER_blaney-pc`. (See
   [blaney-sops-setup.md](blaney-sops-setup.md).) Serving over HTTP removes this from the
   critical path entirely.

WireGuard is **not** a blocker: peer `10.10.0.5` is live on optiplex-fw.

## Steps

*Built as described, with one change: the directory is declarative rather than a manual
`mkdir`.*

### 1. The directory — done by the module

`public-files.nix` carries a tmpfiles rule, matching how every other `/mnt/storage`
subdirectory is created in `media-setup.nix`:

```nix
systemd.tmpfiles.rules = [ "d ${cfg.path} 2775 ${cfg.owner} media -" ];
```

`2775 lando:media` leaves the directory world-readable, which is what lets nginx (running
as its own `nginx` user, in no shared group) read it.

### 2. Populate with hardlinks, not copies

`/mnt/storage` is one btrfs filesystem, so a hardlink costs nothing — same trick as
`mediaLinker`. Quote every path; the MW2 media directory contains spaces **and** literal
`[` `]`:

```bash
ln "/mnt/storage/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs][WwW.GamesTorrents.CoM]/sr-mw2a.iso" /mnt/storage/public/
```

For blaney the better payload is the **finished game directory** from gaming-pc
(`/mnt/games/mw2`, ~15 GB, already IW4x-synced) rather than the ISOs — it skips extraction
on his end. That has to be copied to the NAS first, so it cannot be a hardlink. Tar it so
it is one resumable download:

```bash
tar -C /mnt/games -cf /mnt/nas/public/mw2.tar mw2   # on gaming-pc; /mnt/nas IS the storage share
```

### 3. nginx — `modules/nixos/homelab/public-files.nix`

Built as sketched, as `customConfig.homelab.publicFiles.{enable,path,owner,serverAliases}`,
following the layout rule that a module declares the options it implements. Enabled in
`hosts/optiplex-nas/homelab.nix`. Read the module for the current config.

**The `serverAliases` default is the trap, and it was real.** Restricted peers use 1.1.1.1
and cannot resolve `.lan` at all (see [networking.md](../networking.md), "VPN peer
addressing"), so Blaney reaches the NAS only as `http://192.168.1.76/public/`. nginx
matches on the `Host` header, which will be that literal IP. Confirmed on the NAS *before*
the change:

```bash
curl -s -H 'Host: 192.168.1.76' http://127.0.0.1/ | head -5    # <title>Bazarr</title>
```

`bazarr.lan` sorts first among the vhosts and was therefore nginx's default server, so
without the alias Blaney would have landed in Bazarr's web UI.

**`files.lan` also needs a DNS record**, which the original sketch missed: add `"files"` to
`nasNames` in `modules/nixos/common/lan-records.nix`. That one list feeds both Unbound's
`local-data` and the generated `/etc/hosts` on every client, so both follow from the one
edit. Remote peers never use it — it is for LAN machines.

**Trap: unbound may restart mid-switch and come up on the old config.** After the rebuild,
`files.lan` did not resolve even though `/etc/unbound/unbound.conf` contained the record.
`sudo systemctl restart unbound` fixed it. Check the record resolves rather than assuming
the rebuild applied it:

```bash
dig @127.0.0.1 files.lan +short     # expect 192.168.1.76
```

### 4. No firewall change

Deliberate. Port 80 to `$nas_legacy_ip` is already passed for `<restricted_peers>` and
already `rdr-to $nas_host`. If you find yourself editing `pf.conf`, stop and re-read —
something else is wrong.

## Verification

All of the NAS-side checks below passed on 2026-09-23:

```bash
curl -sI -H 'Host: 192.168.1.76' http://127.0.0.1/public/ | head -1          # 200
curl -sI -H 'Host: files.lan'    http://127.0.0.1/public/ | head -1          # 200
curl -s  -H 'Host: 192.168.1.76' http://127.0.0.1/public/ | grep -o 'mw2[^"]*'
curl -sI -X PUT  -H 'Host: 192.168.1.76' http://127.0.0.1/public/x | head -1 # 403
curl -sI -X POST -H 'Host: 192.168.1.76' http://127.0.0.1/public/x | head -1 # 403
curl -s -r 0-1 -H 'Host: 192.168.1.76' http://127.0.0.1/public/<f> -D - -o /dev/null | head -1   # 206
curl -sI -H 'Host: 192.168.1.76' 'http://127.0.0.1/public/../media/' | head -1                   # 404
dig @127.0.0.1 files.lan +short                                             # 192.168.1.76
```

The `206` matters as much as the `200`: it is what proves a dropped 15 GB download resumes
rather than restarting.

**Not yet done: the remote half.** From a restricted peer with the VPN up — blaney-pc is
the real test, and nothing here substitutes for it:

- `http://192.168.1.76/public/` lists the files in a browser
- a download resumes: `curl -C - -O http://192.168.1.76/public/mw2.tar`
- **`smbclient -L //192.168.1.76 -p 445` still fails.** If SMB became reachable, something
  widened the firewall that should not have.

### Trap: the rebuild can take DNS down for ~20 minutes

Not caused by this change — any rebuild that restarts `mullvad-daemon` can do it, and it is
worth recognising rather than debugging from scratch. On 2026-09-23 the daemon came back
unable to pick a relay:

```
ERROR mullvad_daemon::tunnel: Error: Failed to generate tunnel parameters
 INFO mullvad_daemon: Blocking all network connections, reason: Failure to select a matching tunnel relay
```

Its kill-switch then held the network closed, so unbound's DoT upstreams logged
`SSL_handshake syscall: Connection refused` for 20 minutes until the tunnel came up on its
own. Chicken-and-egg: selecting a relay wants DNS, DNS wants the tunnel. **It self-recovers
— wait before intervening.** Collateral in that window: `media-linker` failed once (exit 7)
and succeeded on its next timer firing.

## Optional: the SMB share for LAN machines

**Not built.** Skipped deliberately in PR #147: no LAN box currently wants the mount, and
it does nothing for the remote users this runbook exists for. The design below stands if
that changes.

Only worth doing if a LAN box wants it mounted; it adds nothing for remote users. Copy the
**private** share pattern in `modules/nixos/homelab/samba.nix` (block 2) — a separate
`/etc/smb-public.conf` and its own systemd unit on its own port (4445 is private, so 4446),
with `read only = yes`, `guest ok = yes`, `map to guest = Bad User`.

Being a *separate instance* is the point: port-level rules cannot distinguish shares, so
adding `public` to the main smbd would mean exposing 445 and `storage` with it.

Copy the private share's guard, and note what it must name:

```nix
unitConfig = {
  RequiresMountsFor = cfg.path;
  ConditionPathIsMountPoint = "/mnt/storage";   # NOT cfg.path
};
```

`/mnt/storage/public` is a directory *on* the storage mount, not a mountpoint. Without
this, a failed storage mount leaves smbd exporting an empty directory on `/` — the exact
failure behind PR #127. Also: **do not quote values** in a hand-written `smb.conf`.
`force user = "lando"` kept its quotes and silently gave clients only the share's group
rights.

`nas-client.nix` hardcodes the `storage` share and always wants `smb-credentials`, so it
would need `share` / `readOnly` / credential-less options before any host could mount this.

## Afterwards

**Done.** `docs/runbooks/blaney/01-install-mw2-iw4x.md` and the "Reaching the media"
section of [mw2-iw4x-source.md](mw2-iw4x-source.md) both describe the HTTP path now;
neither mentions a USB drive. Nothing in the tree still claims blaney-pc has no route to
the NAS.

**Still outstanding: the drop is empty.** Nothing is served until a payload is put in it,
and for MW2 that step belongs on **gaming-pc**, not here — the finished IW4x-synced game
directory only exists there:

```bash
tar -C /mnt/games -cf /mnt/nas/public/mw2.tar mw2    # on gaming-pc; /mnt/nas IS the storage share
```

That is a ~15 GB copy across the LAN mount, so expect it to take a while; the NAS side
needs no action. Once it lands, re-run the verification above and Blaney's runbook works
end to end.

The ISOs can be hardlinked in on the NAS itself at no cost (same btrfs filesystem), as a
fallback for anyone who wants to run the installer rather than take the prepared tree.
Quote the path — it contains spaces **and** literal `[` `]`:

```bash
ln "/mnt/storage/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs][WwW.GamesTorrents.CoM]/sr-mw2a.iso" /mnt/storage/public/
```
