# Runbook: MW2 install media on the NAS, for IW4x on gaming-pc and blaney-pc

**Status: media staged and verified; installation not yet attempted.** Both gaming-pc and
blaney-pc can reach it — gaming-pc over its SMB mount, blaney-pc over the NAS's HTTP drop
since 2026-09-23 (see "Reaching the media"). The two install ISOs sit on the NAS,
checksummed and content-listed. Everything below the "Install" heading is derived from the
release's own readme and from probing the images — it has not been run.

The goal this serves: IW4x (in nixpkgs) needs a complete Modern Warfare 2 installation to
sit on top of. These ISOs are what produce one. IW4x itself is out of scope here.

| | |
|---|---|
| Source | Gamarr grab, `Call of Duty Modern Warfare 2 PROPER-SKIDROW`, MW2 **2009** (not MW II 2022) |
| NAS path | `/mnt/storage/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs][WwW.GamesTorrents.CoM]/` |
| Torrent | deleted, not seeding — the RARs are gone, these ISOs are the only local copy |

## The media

| File | Bytes | sha256 |
|---|---|---|
| `sr-mw2a.iso` (DVD1) | 8450084864 | `d5bb15e47f1f73d674cf2933cacf81cc3dc48d7b47663c44cb3c2b552ebe5e0c` |
| `sr-mw2b.iso` (DVD2) | 3437332480 | `afa0ae7244fe8797beb0c3d1d56cd503725a2a34bdc00864a8c9e8d4e067e72a` |

Plain ISO9660 (`CD001` at offset 0x8001), `lando:media`, mode 664, in a 2775 directory.
Extracted from the release's split RARs with `unrar`, which verified CRCs (`All OK`).

Contents:

```
sr-mw2a.iso   Setup.exe (350085), autorun.inf, mw2.ico
              Setup-1a.bin (1689649792), Setup-1b/1c/1d/1e.bin (1690000000 each)

sr-mw2b.iso   Setup-2a.bin, Setup-2b.bin (1690000000 each), Setup-2c.bin (49738407)
              mw2.ico
              SKIDROW/SKIDROW.exe (71168)
              SKIDROW/iw4mp.exe  (3923544)
              SKIDROW/iw4sp.exe  (3513944)
```

`iw4mp.exe` / `iw4sp.exe` are MW2's **stock** multiplayer and singleplayer binaries with the
DRM stripped — "IW4" is the engine name. They are not IW4x and have nothing to do with it;
neither image contains the string `iw4x` anywhere.

## Reaching the media

The share is `storage` → `/mnt/storage`, `guest ok = no`, `force user = lando`, masks
0664/0775 (`modules/nixos/homelab/samba.nix`).

**gaming-pc — already mounted, no config change needed.**
`hosts/gaming-pc/homelab.nix` sets `nasClient.enable = true`, and `vars.nix` has
`nasViaLanWg = true`, so it mounts `//192.168.100.76/storage` at `/mnt/nas`:

```
/mnt/nas/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs][WwW.GamesTorrents.CoM]/
```

**blaney-pc — reaches the media over HTTP, not SMB.** Since 2026-09-23 the NAS serves a
read-only drop at `http://192.168.1.76/public/` (`customConfig.homelab.publicFiles`,
`docs/runbooks/nas-public-share.md`). Blaney needs the homelab VPN up; he is peer
`10.10.0.5`, and port 80 to the NAS is already in the restricted-peer pf allow-list, so
nothing else has to be opened.

```bash
curl -C - -O http://192.168.1.76/public/mw2.tar     # resumes; ~15 GB
```

Use `curl -C -`, not a plain download — this crosses the WAN to another state.

**Do NOT try to get there over SMB, and do not enable `nasClient`.** This is the trap that
will waste the most time if taken on faith, so the blockers are spelled out. All three are
still true; HTTP routes around them rather than fixing them.

1. **No sops identity.** `hosts/blaney-pc/networking.nix` sets `ssh.enable = false`, so NixOS
   never generates `/etc/ssh/ssh_host_ed25519_key`, and `modules/nixos/sops.nix` derives every
   host's age key from exactly that. `.sops.yaml` still carries the literal
   `age1PLACEHOLDER_blaney-pc`, and `secrets/blaney-pc.yaml` does not exist.
2. **Not a recipient of the credentials.** `nas-client.nix` takes `smb-credentials` from
   `secrets/common.yaml`, whose key group in `.sops.yaml` is lando, asus-laptop, gaming-pc,
   optiplex-nas, mini-server. blaney-pc is absent — and cannot be added until blocker 1 is
   resolved, since there is no key to add.
3. **`pf` blocks SMB for him regardless.** Restricted peers are passed
   `{ 8096, 5055, 5000, 53, 80, 8100 }` to the NAS and then blocked; 445/139 are deliberately
   absent. Full peers *do* get them in the rule immediately above, which is what makes this
   easy to misread as already working. His `AllowedIPs` is `192.168.1.76/32`, so
   `192.168.100.76` is not routable from him at all.

So `customConfig.homelab.nasClient.enable = true` on blaney-pc produces a mount unit that
fails on both credentials and connectivity. Note also that `hosts/blaney-pc/default.nix`
imports no `homelab.nix`, so the file would have to be created *and* added to that import
list — but there is no reason to, now that HTTP works.

Giving blaney-pc a real SMB mount would still mean working through
`docs/runbooks/blaney-sops-setup.md` first (sops identity, then the WireGuard client). That
is worth doing for its own sake, but it is **not** a prerequisite for the MW2 install.

Blaney-pc work follows `docs/hosts/blaney-pc.md`: `blaney/`-prefixed branch, PR only, never
commit to `main` and never merge it yourself.

## Install

### Trap 1 — the Windows installer cannot be bypassed

The obvious automation win would be extracting the game files directly and skipping Wine.
It does not work. The `Setup-*.bin` payloads start with magic `69 64 73 6b 61 33 32 1a`
(`idska32`) — not CAB, not MSCF, not zip/7z/RAR. Tested: `7z` refuses both `Setup.exe` and
a 10 MB head of `Setup-1a.bin` with *"Can not open the file as archive"*.

So `Setup.exe` has to run under Wine/Proton. Budget for that being the fragile step.

### Trap 2 — but the ISOs themselves extract fine, so no loop-mount root is needed

The images are ordinary ISO9660, so `7z` reads them even though it cannot read their
payload. That avoids needing root for `mount -o loop`:

```bash
7z x "sr-mw2a.iso" -o"$WORKDIR"
7z x "sr-mw2b.iso" -o"$WORKDIR"     # same dir, see trap 3
```

`udisksctl loop-setup -r -f` is the rootless mount alternative if a real mount is wanted.

### Sequence

From the release's `Leeme.txt`, verbatim in intent:

1. Unpack / mount DVD1
2. Run `Setup.exe`
3. Supply DVD2 when the installer asks for it
4. Copy the contents of `SKIDROW/` from DVD2 over the install directory, overwriting
5. Play

Installed size lands around 12–13 GB.

### Trap 3 — the disc-2 prompt, and an untested shortcut

Extracting both ISOs into **one** directory puts `Setup-1*.bin` and `Setup-2*.bin`
side by side, which plausibly satisfies the disc-swap prompt without any mount juggling.
This is a hypothesis, not a verified step — it has not been tried. If it fails, fall back
to two mount points and point the installer at the second when asked.

### Trap 4 — do not install across the SMB mount

Copy the ~12 GB local first, then install from local disk. Two reasons: an
InstallShield-style installer doing many small reads over CIFS is painfully slow, and the
mount is `x-systemd.automount` with `x-systemd.idle-timeout=60`, so it is not permanently
mounted — touching the path triggers it, but nothing keeps it up between phases.

### Trap 5 — quote every path

The directory name contains spaces **and** literal `[` and `]`. Unquoted it will break
globbing and shell expansion in any script that touches it.

## Open question for whoever does the IW4x half

What file set IW4x actually requires, and whether it needs the cracked `iw4mp.exe` at all,
has **not** been checked here. IW4x ships its own client binary and its own master server
(MW2's original IWNet matchmaking is long dead), so the stock cracked multiplayer exe may
be redundant for multiplayer and matter only for singleplayer. Read IW4x's own
documentation rather than inheriting that assumption — the only claim this runbook stands
behind is that IW4x installs on top of a complete MW2 installation, and that these ISOs
produce one.
