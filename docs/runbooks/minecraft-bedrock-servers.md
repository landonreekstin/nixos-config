# Runbook: `landon` and `Venator class XvX` as Bedrock servers

**Status: done.** Both worlds are served by their own BDS instance on `mini-server`, each
with a game-control dashboard tile, and both have been verified in game with the builds
visible. This file is kept for the three traps involved, none of which announce themselves.

| world | container | UDP | source device | notes |
|---|---|---|---|---|
| `landon` | `minecraft-bedrock-landon` | 19134 / 19135 | iPod touch 4 | `Generator 0` limited world, content in blocks 0–255 |
| `venator` | `minecraft-bedrock-venator` | 19136 / 19137 | iPhone XR | `Generator 2` flat, spans blocks −160–367 |

Declared in `modules/nixos/homelab/game-servers.nix`, enabled in
`hosts/mini-server/homelab.nix`, tiles in `modules/nixos/homelab/game-control-src/app.py`.
LAN/VPN reachability comes from `rdr-to` rules on optiplex-fw (see `docs/networking.md`).

## Trap 1 — BDS 1.26 defaults to `transport=nethernet`

A 1.26 server writes `transport=nethernet` into a fresh `server.properties`. NetherNet is
Microsoft's WebRTC transport: the server registers with a signaling service and **does not
serve RakNet on its UDP port**, so "Add Server" by IP:port can never connect and the server
does not answer a ping. The log line `Signed in to signaling service successfully` is the
tell.

Fix is `TRANSPORT = "raknet"` in the container `environment`. Older servers (the 19132
`minecraft-bedrock`) predate the property entirely and were never affected.

Ignore the `TRANSPORT TYPE ERROR` block that 1.26 prints claiming NetherNet is the only
supported transport — the next lines say `IPv4 supported, port: NNNNN: Used for gameplay`
and RakNet clients connect fine.

## Trap 2 — `Generator 0` worlds get fenced off from their own terrain

This is the one that cost the most. `landon` is `Generator 0`, a *legacy limited world*
(the old finite 256×256 MCPE map type).

When BDS 1.26 opens such a world it **relocates the spawn** — `SpawnX/Z` went from
128/128 to **580/4** — then computes the limited world's playable boundary around that new
spawn. Every coordinate in the real build area is then rejected with *"Cannot teleport
entities outside of the world"*, and `setworldspawn` is refused with *"The world spawn can
not be set in legacy worlds"*. The player lands in freshly generated terrain hundreds of
blocks away and concludes the save is empty.

**The chunks are never touched.** Measured before and after a BDS open:

| | landon | venator |
|---|---|---|
| chunk columns | 256 → 256 | 458 → 458 |
| non-air blocks | 4,401,773 → **4,401,773** | 525,188 → **525,188** |

**Fix: patch one integer in `level.dat` — `Generator 0 → 1` (infinite) — before BDS opens
the world.** It is a fixed-width `TAG_Int`, so the file length is unchanged and the 8-byte
header's payload-length field needs no adjustment. BDS then preserves the spawn at
128/64/128 and generates no stray chunks. Verified against the real 1.26.51.1 binary.

`Generator 2` worlds like venator are unaffected — its spawn was never modified.

### Two red herrings

Both of these were cited as evidence of corruption. Neither is:

- **`SpawnY = 32767`** is int16 max used as Bedrock's *auto-pick the surface* sentinel.
- **`limitedWorldWidth` / `limitedWorldDepth` = 16** are counted in **chunks**, so 16 = 256
  blocks — correct for landon, not a truncation to a 16-block box. BDS re-adds these even
  when `Generator=1`, and they are inert.

Both appear in the **pristine iPhone XR copy of venator that BDS has never opened**. That
single comparison is what disproves them; when a field looks like damage, check whether an
untouched copy already has it.

## Trap 3 — "the server opened it" is not verification

A headless server opens, upgrades and serves a world without ever drawing a block, so a
clean log cannot detect unreadable or unreachable terrain. An earlier session reported
"24/24 worlds pass" from exactly this signal; 17 of them render empty.

Verify one of two ways:

1. **Count blocks.** Parse the LevelDB directly and compare non-air block totals before and
   after. Mojang LevelDB uses **raw deflate** (compression type 4) so stock readers fail;
   parse the SST footer → index → data blocks, strip the 8-byte internal-key suffix
   (`k[:-8]`), and read `.log` as well as `.ldb` — the `.log` holds the newest state and a
   parser that globs only `*.ldb` reads a stale world.
2. **Look at it.** Join with a real client and find the build.

For fast iteration without a client or a container runtime, BDS can be run straight from
the install tree on any NixOS box:

```bash
rsync -a --exclude worlds/ -e "ssh -J lando@192.168.1.189" \
  lando@192.168.100.103:/var/lib/game-servers/minecraft-bedrock-landon/ ./bds/
cd bds && NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#steam-run \
  -c steam-run env LD_LIBRARY_PATH=. ./bedrock_server-1.26.51.1
```

Two gotchas: `steam-run` is unfree, and its `bwrap` sandbox could not `chdir` into `/tmp`
here — keep the tree under `/home`.

## Source worlds

Pristine iOS extractions live on gaming-pc under a **per-device** directory, not a flat one:

```
~/Games/Minecraft-worlds/ipod-touch-4/minecraft-worlds/landon
~/Games/Minecraft-worlds/iphone-xr/minecraft-worlds/Venator class XvX
```

They are read-only on purpose and must never be opened by BDS — its upgrade is one-way.
Copy first, `chmod -R u+w` the copy. The once-converted intermediates from mcpelauncher
1.14.60.5 are at `mini-server:~/minecraft-worlds/` and in the mcpelauncher data dir on
gaming-pc; those are the right input for any further conversion, since Chunker and friends
will not read the original LegacyTerrain format (Chunker's floor is Bedrock 1.12.0).

Background on the LegacyTerrain conversion itself: memory note
`mcpe-legacy-world-recovery`.

## Swapping a world in

```bash
sudo systemctl stop docker-minecraft-bedrock-landon
sudo rm -rf /var/lib/game-servers/minecraft-bedrock-landon/worlds/landon
sudo cp -a /tmp/converted-landon /var/lib/game-servers/minecraft-bedrock-landon/worlds/landon
sudo chown -R root:root /var/lib/game-servers/minecraft-bedrock-landon/worlds/landon
sudo systemctl start docker-minecraft-bedrock-landon
```

Discarding the old world also discards its player records, so the next join is treated as a
first-time join and lands on the repaired world spawn — no teleport needed. `sudo` on
mini-server prompts for a password, so lando has to be present.
