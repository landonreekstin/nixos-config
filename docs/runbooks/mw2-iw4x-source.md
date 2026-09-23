# Runbook: MW2 install media on the NAS, for IW4x on gaming-pc and blaney-pc

**Status: installed and playing on gaming-pc (2026-09-23).** `mw2-install` built it from
these ISOs, IW4x synced onto it, and multiplayer is confirmed working. blaney-pc is not
done yet.

Both hosts can reach the media — gaming-pc over its SMB mount, blaney-pc over the NAS's
HTTP drop since 2026-09-23 (see "Reaching the media"). The two install ISOs sit on the NAS,
checksummed and content-listed. Everything under "Install" has now actually been run —
where an earlier version of this document guessed, the guess is marked corrected rather
than quietly deleted.

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

Three blockers, all verified against the current tree and the live firewall:

1. **Samba is blocked at the firewall.** Blaney is a *restricted* peer. `/etc/pf.conf`
   on optiplex-fw passes restricted peers to the NAS on
   `port { 8096, 5055, 5000, 53, 80, $article2pod_port }` and then
   `block in quick on wg0 from <restricted_peers>`. 445 and 139 are deliberately absent,
   so a CIFS mount cannot connect however well it is configured. (Full peers *do* get
   445/139 on `$nas_legacy_ip` — that rule is right above it, which is what makes this
   easy to misread.)
2. **No sops identity.** `hosts/blaney-pc/networking.nix` sets `ssh.enable = false`, so NixOS
   never generates `/etc/ssh/ssh_host_ed25519_key`, and `modules/nixos/sops.nix` derives every
   host's age key from exactly that. `.sops.yaml` still carries the literal
   `age1PLACEHOLDER_blaney-pc`, and `secrets/blaney-pc.yaml` does not exist.
3. **Not a recipient of the credentials.** `nas-client.nix` takes `smb-credentials` from
   `secrets/common.yaml`, whose key group in `.sops.yaml` is lando, asus-laptop, gaming-pc,
   optiplex-nas, mini-server. blaney-pc is absent — and cannot be added until blocker 2 is
   resolved, since there is no key to add.
3. **`pf` blocks SMB for him regardless.** Restricted peers are passed
   `{ 8096, 5055, 5000, 53, 80, 8100 }` to the NAS and then blocked; 445/139 are deliberately
   absent. Full peers *do* get them in the rule immediately above, which is what makes this
   easy to misread as already working. His `AllowedIPs` is `192.168.1.76/32`, so
   `192.168.100.76` is not routable from him at all.

So `customConfig.homelab.nasClient.enable = true` on blaney-pc produces a mount unit that
fails, and should not be attempted. Note also that `hosts/blaney-pc/default.nix`
imports no `homelab.nix`, so the file would have to be created *and* added to that import
list — but there is no reason to, now that HTTP works.

Giving blaney-pc a real SMB mount would still mean working through
`docs/runbooks/blaney-sops-setup.md` first (sops identity, then the WireGuard client). That
is worth doing for its own sake, but it is **not** a prerequisite for the MW2 install.

Blaney-pc work follows `docs/hosts/blaney-pc.md`: `blaney/`-prefixed branch, PR only, never
commit to `main` and never merge it yourself.

## Install

**This is now automated.** `customConfig.programs.iw4x.enable` (see
`modules/nixos/programs/iw4x.nix`) provides two commands:

| | |
|---|---|
| `mw2-install` | ISOs → a complete MW2 installation. No Wine, no display, no interaction. |
| `iw4x` | syncs the IW4x files into that installation, then launches it under Proton. |

Everything below is why it works the way it does. **Done on gaming-pc 2026-09-23**;
the whole run is about 25 GB of I/O and took roughly 45 minutes, most of it reading the
ISOs off the NAS at ~8 MB/s.

### Trap 1 — the installer CAN be bypassed. `idska32` is Inno Setup.

> **Corrected 2026-09-23.** This section previously said the installer could not be
> bypassed and that Wine was unavoidable. That was wrong, and it was the single most
> expensive claim in this document.

The reasoning that produced the wrong answer was: `7z` cannot open `Setup.exe`, `7z`
cannot open the `Setup-*.bin` payloads, the payloads start with an unidentified magic
`69 64 73 6b 61 33 32 1a` (`idska32`), therefore the format is unknown and the Windows
installer is the only way in.

`idska32` is not unknown. It is **Inno Setup's data-slice signature**, and `Setup.exe` is
an Inno Setup 5.3.3 installer. `7z` not reading it says nothing — `innoextract` is the
tool for this format, and it reads both the executable and every slice:

```bash
innoextract -i Setup.exe      # "Call of Duty Modern Warfare 2" - setup data version 5.3.3
innoextract -l -m Setup.exe   # 347 files
innoextract -e -m -d OUT Setup.exe
```

Output lands in `OUT/app/` and is the finished game: 31 `main/*.iwd`, 98
`zone/english/*.ff`, `miles/`, `iw4sp.exe`, `iw4mp.exe`, `binkw32.dll`, `mss32.dll` —
about 12 GB. `-m` drops Inno's own scaffolding (including `ISSkin.dll`).

**The lesson worth keeping: an unrecognised magic is a search term, not a dead end.**

### Trap 2 — and running the installer does not work anyway

Worth knowing, because it is the path anyone would try first. Under Proton the installer
opens a black window and dies with:

```
cannot import dll:C:\users\steamuser\AppData\Local\Temp\is-UHMNG.tmp\isskin.dll
```

That is the installer's *skinned* UI: Inno Setup extracts `ISSkin.dll` to a temp
directory and loads it, and it fails under Wine. There is no click-through past it — the
wizard never draws. So extraction is not merely the tidier route, it is the only one that
works here.

### Trap 3 — the ISOs themselves extract fine, so no loop-mount root is needed

The images are ordinary ISO9660, so `7z` reads them even though it cannot read the Inno
slices inside. That avoids needing root for `mount -o loop`:

```bash
7z x "sr-mw2a.iso" -o"$WORKDIR"
7z x "sr-mw2b.iso" -o"$WORKDIR"     # same dir, see trap 4
```

`udisksctl loop-setup -r -f` is the rootless mount alternative if a real mount is wanted.

### Trap 4 — both ISOs must unpack into ONE directory

Not for the disc-swap prompt (there is no prompt now — nothing interactive runs). The
payload is genuinely split across discs: `Setup-1a`…`1e` on DVD1 and `Setup-2a`…`2c` on
DVD2. `innoextract` needs every slice side by side or it stops partway through.

### Trap 5 — do not install across the SMB mount

Unpack the ISOs to local disk first. The mount is `x-systemd.automount` with
`x-systemd.idle-timeout=60`, so it is not held open between phases. `mw2-install` reads
the ISOs straight off the mount (one long sequential read, which CIFS handles fine) but
writes every intermediate locally.

Budget the space: ~12 GB unpacked ISOs + ~12 GB extracted payload + ~13 GB installed
game ≈ **37 GB peak**, settling to ~15 GB once staging is removed and IW4x has synced.

### Trap 6 — quote every path

The directory name contains spaces **and** literal `[` and `]`. Unquoted it will break
globbing and shell expansion in any script that touches it.

### Trap 7 — `binkw32.dll` / `mss32.dll` do not mean the game is installed

The IW4x launcher checks exactly those two files (`REQUIRED_GAME_FILES` in its
`game_files.rs`) — but it also **downloads both itself** as part of `iw4x-rawfiles`.
Point it at an empty directory with `--ignore-required-files` and you get `binkw32.dll`,
`mss32.dll`, `iw4x.exe`, `iw4x.dll`, `zone/{dlc,patch,zonebuilder}` and `miles/`: 775 MB
that looks like an install and contains no game.

Test for `main/*.iwd` instead. That is base-game data and nothing IW4x ships creates it.

### Sequence

What `mw2-install` does, and what to do by hand if it ever needs redoing:

1. `7z x` both ISOs into one staging directory
2. `innoextract -e -m -d EXTRACT Setup.exe` from that directory
3. move `EXTRACT/app/*` into the install directory
4. copy `SKIDROW/*` from the media over it, overwriting (DRM-free `iw4mp.exe` /
   `iw4sp.exe` — MW2's own binaries, nothing to do with IW4x)
5. `iw4x` — the launcher syncs ~744 MB of client + rawfiles + 81 DLC files

Each of steps 1–2 is skipped if its output is already present, so a failure late in the
run does not repeat the expensive parts. `--reextract` forces them.

## The IW4x half — answered

The earlier open question was what file set IW4x actually needs and whether the cracked
`iw4mp.exe` matters at all.

IW4x ships its own client (`iw4x.exe` + `iw4x.dll`) and its own master server, and it is
what you launch. It needs the base game's **data** — `main/*.iwd`, `zone/english/*.ff` —
not the base game's executables. The SKIDROW binaries are still worth copying (they are
step 4 of the release's own instructions, and they are what makes singleplayer run
without the DRM), but multiplayer does not go through them.

Launching is `umu-run iw4x.exe` under Proton-GE, not wine — see the module's own comments
for why, and for the `umu` vs `umu-run` detection bug that makes letting the launcher
start the game itself the wrong choice.
