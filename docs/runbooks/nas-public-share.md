# Runbook: a guest read-only `public` Samba share on optiplex-nas

**Status: designed, not built.** Do this in a session **on optiplex-nas** — the samba half
cannot be verified from anywhere else — plus one live `pf` edit on optiplex-fw.

**Why:** restricted VPN peers (Blaney, Chris, …) have no way to receive a file from the
homelab. The immediate need is ~12 GB of MW2 install media for
[mw2-iw4x-source.md](mw2-iw4x-source.md), but the general shape — "somewhere I can drop a
file for a VPN user" — keeps coming up.

## Why not just let them mount `storage`

Three separate reasons, all verified 2026-09-23. Any one of them alone would be enough.

1. **`pf` blocks it.** `/etc/pf.conf` on optiplex-fw passes restricted peers to the NAS on
   `port { 8096, 5055, 5000, 53, 80, $article2pod_port }` and then
   `block in quick on wg0 from <restricted_peers>`. 445/139 are deliberately absent.
   (Full peers *do* get 445/139 on `$nas_legacy_ip` in the rule immediately above — which
   is what makes this easy to misread as working.)
2. **The share cannot be made read-only per-user.** There is one `storage` share with
   `read only = no` and `force user = lando`, behind a single `smb-credentials` secret.
   Handing that credential to a restricted peer grants full write to all 2.8 TB. A
   client-side `ro` mount option is **not** enforcement — the client chooses it, and can
   choose otherwise.
3. **blaney-pc has no sops identity**, so it cannot receive `smb-credentials` anyway.
   `.sops.yaml` still carries `age1PLACEHOLDER_blaney-pc` and `secrets/blaney-pc.yaml`
   does not exist. (See [blaney-sops-setup.md](blaney-sops-setup.md).)

Note that WireGuard is **not** a blocker: peer `10.10.0.5` is live on optiplex-fw.

## The design

A second smbd instance on its own port, serving one directory guest-readable and
read-only. This copies the existing **private** share in
`modules/nixos/homelab/samba.nix` (block 2), which already runs a separate
`/etc/smb-private.conf` + its own systemd unit on port 4445 — so the pattern is proven
here, not invented.

Two properties matter, and both come from it being a *separate instance*:

- **`pf` opens only that port.** Port-level rules cannot distinguish shares, so adding a
  share to the main smbd would mean opening 445 and making `storage` reachable too. With
  its own port, the main instance stays unreachable to restricted peers and `storage`
  needs no hardening — the ACL and the samba config would both have to be wrong before
  anything leaks.
- **Guest access needs no secret.** The VPN *is* the authentication boundary: the port is
  only reachable from `<restricted_peers>` on `wg0`. That means no samba user, no new sops
  secret, and **no blaney-pc sops identity** — which takes `blaney-sops-setup.md` off the
  critical path entirely.

## Steps

### 1. `modules/nixos/homelab/samba.nix` — add `public`

Mirror the `private` option block and its `mkIf` in the existing `mkMerge`:

```nix
customConfig.homelab.samba.public = {
  enable = mkOption { type = types.bool; default = false; ... };
  port   = mkOption { type = types.port; default = 4446; ... };  # 4445 is private
  path   = mkOption { type = types.str;  default = "/mnt/storage/public"; ... };
};
```

The config block writes `environment.etc."smb-public.conf"` and a `samba-public`
systemd unit, both copied from the private ones with these differences:

```
[global]
smb ports = ${toString cfg.public.port}
netbios name = ${hostName}-public
pid directory = /run/samba-public
ncalrpc dir = /run/samba-public/ncalrpc
security = user
map to guest = Bad User
guest account = nobody

[public]
path = /mnt/storage/public
browseable = yes
read only = yes          # the whole point
guest ok = yes
guest only = yes
```

**Copy the private share's guard**, and for the same reason it exists there:

```nix
unitConfig = {
  RequiresMountsFor = cfg.public.path;
  ConditionPathIsMountPoint = "/mnt/storage";
};
```

`/mnt/storage/public` is a *directory on* the storage mount, not a mountpoint itself, so
the condition must name `/mnt/storage`. Without it, a failed storage mount leaves smbd
exporting an empty directory on `/` — the exact failure that produced PR #127.

**Do not quote values** in the hand-written conf. `force user = "lando"` kept its quotes
and silently gave clients only the share's group rights; there is no `force user` here,
but the trap applies to every value in this file.

### 2. Create the directory on the NAS

```bash
sudo mkdir -p /mnt/storage/public
sudo chown lando:media /mnt/storage/public
sudo chmod 2775 /mnt/storage/public
```

### 3. Populate it with hardlinks, not copies

`/mnt/storage` is a single btrfs filesystem, so a hardlink costs nothing. Same trick as
`mediaLinker`:

```bash
ln "/mnt/storage/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs][WwW.GamesTorrents.CoM]/sr-mw2a.iso" /mnt/storage/public/
ln "…/sr-mw2b.iso" /mnt/storage/public/
```

Quote every path — that directory name contains spaces **and** literal `[` `]`.

A hardlink shares permissions with its target, so the file is world-readable either way;
read-only is enforced by the share, not the inode.

### 4. `hosts/optiplex-nas/homelab.nix`

```nix
samba.public.enable = true;
```

`rebuild` on the NAS, then confirm locally before touching the firewall:

```bash
systemctl status samba-public
smbclient -N -L //127.0.0.1 -p 4446
smbclient -N //127.0.0.1/public -p 4446 -c 'ls'
```

### 5. optiplex-fw — one pf rule

Edit `/etc/pf.conf`, **above** the `block in quick on wg0 from <restricted_peers>` line:

```
pass in quick on wg0 proto tcp from <restricted_peers> to $nas_legacy_ip \
    port 4446 rdr-to $nas_host keep state
```

The `rdr-to $nas_host` is not optional: `wg0` is filtered on the **pre-rdr** destination,
so a rule matching `$nas_host` directly never fires. This is the bug that silently blocked
every restricted peer after the NAS migration.

```bash
doas pfctl -nf /etc/pf.conf     # parse check FIRST
doas pfctl -f /etc/pf.conf
```

Then commit the live file to `~/openbsd-dotfiles/` on optiplex-fw — the live files are the
source of truth, and the repo drifts if this is skipped.

### 6. Client side

`modules/nixos/homelab/nas-client.nix` hardcodes the `storage` share and always wants
`smb-credentials`, so it cannot mount this as-is. Either add `share` / `readOnly` /
credential-less options to it, or write a small sibling module. Mount options want
`guest,ro,port=4446`.

## Verification

From a restricted peer with the VPN up (blaney-pc is the real test):

```bash
smbclient -N -L //192.168.1.76 -p 4446      # lists [public]
smbclient -N //192.168.1.76/public -p 4446 -c 'ls'
```

Then prove the two things that actually matter:

- **Writes are refused.** `smbclient … -c 'put /etc/hostname test'` must fail.
- **`storage` is still unreachable.** `smbclient -L //192.168.1.76 -p 445` from that same
  peer must time out. If it connects, the pf rule is too wide — stop and fix it.

## Afterwards

Once this exists, blaney-pc can fetch its own MW2 media and the USB step in
`docs/runbooks/blaney/` goes away. Update both that runbook and the "Reaching the media"
section of [mw2-iw4x-source.md](mw2-iw4x-source.md), which currently says he has no path
to the NAS at all.
