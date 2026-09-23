# Runbook: a read-only `public` drop for VPN users on optiplex-nas

**Status: designed, not built.** Do this in a session **on optiplex-nas** — none of it can
be verified from anywhere else.

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

### 1. The directory

```bash
sudo mkdir -p /mnt/storage/public
sudo chown lando:media /mnt/storage/public
sudo chmod 2775 /mnt/storage/public
```

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
tar -C /mnt/games -cf /mnt/storage/public/mw2.tar mw2   # run on gaming-pc, write over the NAS mount
```

### 3. nginx — a new module beside the other homelab services

Add `customConfig.homelab.publicFiles.{enable,path}` in
`modules/nixos/homelab/public-files.nix`, following the layout rule that a module declares
the options it implements. The vhost goes alongside the ones in `reverse-proxy-nas.nix`:

```nix
services.nginx.virtualHosts."files.lan" = {
  serverAliases = [ "192.168.1.76" ];   # see the DNS trap below
  locations."/public/" = {
    alias = "${cfg.path}/";
    extraConfig = ''
      autoindex on;
      autoindex_exact_size off;
      autoindex_localtime on;
      # GET/HEAD only -- nothing here should ever accept an upload.
      limit_except GET HEAD { deny all; }
    '';
  };
};
```

**The `serverAliases` line is the trap.** Restricted peers use 1.1.1.1 and cannot resolve
`.lan` at all (see [networking.md](../networking.md), "VPN peer addressing"), so Blaney
reaches the NAS only as `http://192.168.1.76/public/`. nginx matches on the `Host` header,
which will be that literal IP — without the alias he gets whichever vhost happens to be
nginx's default, not the file listing.

Then enable it in `hosts/optiplex-nas/homelab.nix` and `rebuild` on the NAS.

### 4. No firewall change

Deliberate. Port 80 to `$nas_legacy_ip` is already passed for `<restricted_peers>` and
already `rdr-to $nas_host`. If you find yourself editing `pf.conf`, stop and re-read —
something else is wrong.

## Verification

On the NAS:

```bash
curl -sI -H 'Host: 192.168.1.76' http://127.0.0.1/public/ | head -1     # 200
curl -s  -H 'Host: 192.168.1.76' http://127.0.0.1/public/ | grep -o 'mw2[^"]*'
curl -sI -X PUT -H 'Host: 192.168.1.76' http://127.0.0.1/public/x | head -1   # 403
```

From a restricted peer with the VPN up — blaney-pc is the real test:

- `http://192.168.1.76/public/` lists the files in a browser
- a download resumes: `curl -C - -O http://192.168.1.76/public/mw2.tar`
- **`smbclient -L //192.168.1.76 -p 445` still fails.** If SMB became reachable, something
  widened the firewall that should not have.

## Optional: the SMB share for LAN machines

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

Update `docs/runbooks/blaney/01-install-mw2-iw4x.md`, which currently tells Claude the
media arrives on a USB drive, and the "Reaching the media" section of
[mw2-iw4x-source.md](mw2-iw4x-source.md), which says blaney-pc has no path to the NAS.
