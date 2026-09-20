# Runbook: host `landon` and `Venator class XvX` as Bedrock servers

**Run this on `mini-server`.** It owns the game servers and the game-control
dashboard, and the containers can only be started and verified there.

Goal: two recovered Minecraft worlds served as independently start/stoppable
Bedrock instances, each with its own tile on the game-control dashboard.

## The worlds are already staged

```
mini-server:~/minecraft-worlds/landon                 1.9M
mini-server:~/minecraft-worlds/Venator class XvX      1.4M
```

| world | StorageVersion | Generator | subchunks | minClient | notes |
|---|---|---|---|---|---|
| `landon` | 8 | **0 — limited 256×256** | 1,354 | 1.14.0.9 | creative; content only in blocks 0–255 on both axes |
| `Venator class XvX` | 8 | 2 (flat) | 604 | 1.18.0.0 | references a resource pack that is not in the extraction |

## Use these copies. Do not substitute the originals

These came off an iPod touch 4 / iPhone 5c and originally stored terrain as
**`LegacyTerrain`** (LevelDB key tag `0x30`, 83,200-byte values). **Bedrock 1.18
and newer — including BDS 1.26 — cannot read that format and do not say so.**
They treat the world as new, relocate spawn and player to a seed-derived spot,
generate fresh terrain there, and serve that instead. The original chunks are
left untouched and unread, so the failure looks exactly like an empty world.

`landon` was converted to modern subchunks by opening it once in **mcpelauncher
1.14.60.5**, which rewrote all 256 columns in a single open. The staged copy is
that converted one. Re-copying the pristine original from
`gaming-pc:~/Games/Minecraft-worlds/` would silently undo this. Full background:
memory note `mcpe-legacy-world-recovery`.

The pristine originals on gaming-pc are read-only and stay the backstop; BDS
upgrades a world **one-way** on first load.

## Resolve the existing bedrock setup first

`minecraft-bedrock` is currently defined **twice, inconsistently**:

- `modules/nixos/homelab/game-servers.nix` declares an OCI container mounting
  `${cfg.dataDir}/minecraft-bedrock:/data`.
- `/var/lib/game-servers/minecraft-bedrock/docker-compose.yml` (hand-written,
  not in the repo) mounts `./data:/data`.

So the live BDS install lives in `/var/lib/game-servers/minecraft-bedrock/data/`
(BDS 1.26.21.1, world `Bedrock level`), while the declared container would see
the parent — containing only `data/` and `docker-compose.yml` — and bootstrap a
fresh server. Both also use container name `minecraft-bedrock`, so they collide.

Decide which is authoritative before adding anything. The repo-declared path is
the one to keep; the compose file predates it.

## Work

Two worlds require **two BDS instances** — one server hosts one world.

1. **`modules/nixos/homelab/game-servers.nix`**
   - Add two option blocks alongside `minecraftBedrock`, following its shape
     (`enable`, `port`, `portV6`).
   - Add two OCI containers modelled on the existing `minecraft-bedrock` one
     (`image = "itzg/minecraft-bedrock-server"`, `autoStart = false`,
     `environment.EULA = "TRUE"`, a `${cfg.dataDir}/<name>:/data` volume).
   - Add matching `systemd.tmpfiles.rules` entries, guarded by the new
     `enable` flags like the others.
   - Ports: 19132/19133 are taken. Use distinct UDP pairs, e.g. 19134/19135 and
     19136/19137.

2. **`modules/nixos/homelab/game-control-src/app.py`**
   - Add two entries to `SERVERS` with `"rcon": False, "bedrock": True`, matching
     the existing `minecraft-bedrock` entry. `container` must equal the OCI
     container name — the dashboard drives `systemctl start/stop docker-<container>`.

3. **World placement** — inside each server's data dir:
   - put the world at `worlds/<folder>/`
   - set `level-name=<folder>` in `server.properties`
   - folder names contain no spaces for `landon`; consider renaming
     `Venator class XvX` to `venator` to avoid quoting problems in
     `server.properties`. The in-game name comes from `LevelName` inside
     `level.dat`, not the folder, so renaming the folder is safe and invisible.

4. **Enable on the host** in `hosts/mini-server/homelab.nix` next to the existing
   `minecraftBedrock.enable`.

## Verification

Per the repo's commit rules, verify before committing.

1. `systemctl start docker-<container>`, then read the log:
   - `Opening level 'worlds/<folder>/db'` naming the right world
   - `Server started.`
   - no `ERROR` lines (a missing-resource-pack `WARN` on Venator is expected and
     harmless — geometry is unaffected)
2. Start and stop both from the dashboard; confirm the tiles track state.
3. **Connect with a real Bedrock client and confirm the build is visible.** This
   is the step that matters. A clean server log proves only that the world
   opened — it does not prove the terrain is readable, which is precisely the
   failure mode these worlds have. In `landon`, everything is inside blocks
   0–255 on both axes, with the largest structures around X 96–111, Z 208–255.

## Risks

- **`landon` is a `Generator 0` limited world** (finite 256×256). Whether BDS
  handles that sanely is untested — verify this early, it is the main unknown.
- `sudo` on mini-server prompts for a password, so lando needs to be present for
  privileged steps.
- Adding UDP ports only exposes them on the server LAN. External access would
  need forwards on optiplex-fw — see `docs/networking.md`.
