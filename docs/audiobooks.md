# Audiobooks

The audiobook stack on **optiplex-nas**: an *arr that grabs books, and a player that
serves them.

```
Prowlarr ─► Bookshelf ─► Transmission (category bookshelf)
               │  ▲              │
               │  └ metadata ── rreading-glasses ─► api.hardcover.app
               ▼                 ▼
   /mnt/storage/media/audiobooks ◄─ import
               │
               ▼
   Audiobookshelf  (books.lan, iOS/Android apps)
```

| Piece | Module | URL | Runs as |
|---|---|---|---|
| Bookshelf | `homelab/bookshelf.nix` | `bookshelf.lan` / `:8787` | OCI container, `bookshelf:media` |
| Provisioner | `homelab/bookshelf-provision.nix` | - | oneshot |
| rreading-glasses | `homelab/rreading-glasses.nix` | `127.0.0.1:8788` only | OCI container + native Postgres |
| Audiobookshelf | `homelab/audiobookshelf.nix` | `books.lan` / `:13378` | native `services.audiobookshelf` |

## Why Bookshelf and not Readarr

Readarr was retired upstream in mid-2025, and the metadata server it depends on went
with it, so stock Readarr can no longer add books. (nixpkgs still carries
`services.readarr`, frozen at 0.4.18.) [Bookshelf](https://github.com/pennydreadful/bookshelf)
is the maintained fork. Its `hardcover-*` images use metadata from
[Hardcover](https://hardcover.app), served through
[rreading-glasses](https://github.com/blampe/rreading-glasses). Bookshelf still
identifies as Readarr: its API is Readarr's `/api/v1`, and Prowlarr links to it as a
**Readarr** app.

Hardcover images are **not** compatible with an old Readarr database. Fresh installs
only.

## Why a self-hosted metadata proxy

The image ships pointed at the shared `https://hardcover.bookinfo.pro`. In October 2026
that instance was rate-limited badly enough that every search hung until the 100 s
timeout. Other self-hosters reported the same thing. `rreading-glasses.nix` runs a
private copy against our own Hardcover API token, and the provisioner points
Bookshelf's metadata source (`/api/v1/config/development`, which the UI never links
to) at `http://127.0.0.1:8788`.

Its database is just a metadata cache that grows as it is queried. It lives in the
NAS's native Postgres with loopback trust auth, so there is no DB password.

### The Hardcover token

`sops secrets/optiplex-nas.yaml`, key `hardcover-auth`. The value is the **whole
header**, including `Bearer `:

```yaml
hardcover-auth: Bearer eyJhbGciOi...
```

Get it from hardcover.app → avatar → Settings → **Hardcover API**. **Hardcover
expires API tokens every January 1.** When searches start failing in the new year,
regenerate the token, update the secret, `rebuild`, then
`systemctl restart docker-rreading-glasses`.

## What is declarative and what isn't

**Declarative**, converged by `bookshelf-provision` on every boot and rebuild:
- the root folder `/mnt/storage/media/audiobooks`, defaulting to the **Spoken**
  (audiobook) quality profile
- the Transmission download client, category `bookshelf`. The field is called
  `musicCategory` because Readarr was forked from Lidarr.
- the metadata source

Deleting any of these in the UI is not durable; the next run puts them back.

**Set by hand, once, in the UIs** (kept in each app's own DB):
- **Prowlarr → Settings → Apps → + → Readarr.** Prowlarr server
  `http://localhost:9696`, Readarr server `http://localhost:8787`, and the API key
  from Bookshelf → Settings → General. Indexers then sync over automatically.
- **Audiobookshelf first run** (`books.lan`): create the root user, then add a
  library of type *Audiobooks* with folder `/mnt/storage/media/audiobooks`. Phone
  apps log in to `http://books.lan` (or `http://192.168.1.76:13378` over VPN).

## Containers, users and paths

- Both containers are host-networked, like article2pod's kokoro.
- Bookshelf mounts `/mnt/storage/downloads` and the library at their **host paths**,
  so Transmission's reported paths resolve unchanged. No remote path mapping is
  needed, and imports can hardlink.
- Bookshelf is a linuxserver image and takes numeric `PUID`/`PGID`. Neither the
  `bookshelf` user nor the `media` group has a pinned id, so
  `docker-bookshelf.preStart` writes them to `/run/bookshelf/env`. `UMASK=002` keeps
  imports group-writable, for the same reason as the `UMask` overrides in `arr.nix`.

## Bumping the images

Both are pinned by digest.

- **Bookshelf**: list tags with
  ```bash
  tok=$(curl -s "https://ghcr.io/token?scope=repository:pennydreadful/bookshelf:pull" | jq -r .token)
  curl -s -H "Authorization: Bearer $tok" https://ghcr.io/v2/pennydreadful/bookshelf/tags/list?n=1000 | jq -r '.tags[]' | grep hardcover | sort -V | tail
  ```
  Then `docker pull` the tag, read the digest with
  `docker inspect --format='{{index .RepoDigests 0}}'`, and set `tag@digest` in
  `bookshelf.nix`.
- **rreading-glasses**: upstream publishes only the moving `hardcover` tag. Pull it,
  then copy the digest into `rreading-glasses.nix`.
