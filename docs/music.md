# Music stack (optiplex-nas)

The music equivalent of the film/TV pipeline, and *not* a straight copy of it — two things
forced a different shape:

- **Jellyseerr has no music support at all.** It is movies and TV only. So music gets its
  own request portal, [Ombi](https://ombi.io/).
- **Public torrent indexers are thin on music.** So Soulseek (`slskd`) is wired in as a
  second source alongside Prowlarr/Transmission, bridged to Lidarr by `soularr`.

```
ombi.lan   :5010   requests (Jellyfin accounts, approval)  ─┐
lidarr.lan :8686   album manager                           ─┤
                     ├─ prowlarr.lan ── transmission.lan ───┤
                     └─ soularr ── slskd.lan :5030 ─────────┤
                                                            ▼
                                     /mnt/storage/media/music
                                                            │
                           ┌────────────────────────────────┤
                 music.lan :4533   Navidrome (web + Subsonic apps)
                 jellyfin.lan      Jellyfin, "Music" library
```

| Service | Port | Host name | Module |
|---|---|---|---|
| Lidarr | 8686 | `lidarr.lan` | `homelab/arr.nix` (+ `lidarr-provision.nix`) |
| Navidrome | 4533 | `music.lan` | `homelab/navidrome.nix` |
| Ombi | **5010** | `ombi.lan` | `homelab/ombi.nix` |
| slskd | 5030 web / 50300 Soulseek | `slskd.lan` | `homelab/slskd.nix` |
| soularr | 8265 | `soularr.lan` | `homelab/soularr.nix` |

Ombi is on **5010, not its upstream default of 5000** — `nix-serve` already has 5000 on this
host (`homelab/nix-cache.nix`).

## Directory layout

Everything is `2775 lando:media` (SGID) and every service runs with `UMask=0002`, which is
what lets four different service users hand files to each other.

```
/mnt/storage/media/music              Lidarr writes; Navidrome + Jellyfin read
/mnt/storage/downloads/torrents/lidarr  Transmission, category "lidarr"
/mnt/storage/downloads/slskd            slskd completed downloads
/mnt/storage/downloads/slskd-incomplete slskd in-flight
```

The music library is **one shared library**, not per-user like `media/users/<name>/{movies,tv}`.
`media-linker` builds those from Jellyseerr requests, and Jellyseerr has no music concept.

## How soularr fits

`soularr` is the piece that makes Lidarr + slskd an actual pipeline rather than two separate
tools. Every 15 minutes (`SCRIPT_INTERVAL`) it reads Lidarr's missing-albums list, searches Soulseek, downloads
the best match, assembles it into a tidy album folder inside `/mnt/storage/downloads/slskd/`, and fires
Lidarr's `DownloadedAlbumsScan` command at that folder.

Three consequences worth knowing:

- **There is no slskd download client in Lidarr, and there should not be.** soularr bypasses
  Lidarr's download-client machinery entirely. Only Transmission is registered.
- **The two `download_dir` keys in `config.ini` are two views of ONE directory**, not two
  directories. From `soularr.py` (~line 776):

  ```python
  import_folder_fullpath = slskd_download_dir  + folder_name   # where it writes
  lidarr_import_fullpath = lidarr_download_dir + folder_name   # what it tells Lidarr
  ```

  soularr assembles the album inside the *slskd* download dir and never writes anywhere
  else; `[Lidarr] download_dir` is purely a path translation — "what does that same
  directory look like to Lidarr?". Lidarr runs natively here, so it is the plain host path
  `/mnt/storage/downloads/slskd`, while the container sees `/downloads`. Point it at some
  other directory and every album fails with
  `Folder/File specified for import scan [...] doesn't exist`, because Lidarr is handed a
  path that by construction nothing ever creates.
- **soularr is not in nixpkgs**, so it runs as the upstream container, pinned by digest.
  Two things about how it is wired that are easy to get wrong if you rewrite the module:
  it is a **long-running unit, not a oneshot on a timer** — the image does not exit after a
  pass, it loops internally on `SCRIPT_INTERVAL` and serves its web UI alongside, so a timer
  would just mean every run hangs until the start timeout. And it is a hand-written unit
  rather than a `virtualisation.oci-containers` entry (as `article2pod`'s kokoro container
  is) because oci-containers cannot express `--user`, and soularr must run as `slskd:media` —
  root-owned results would be un-importable by Lidarr.

`config.ini` is rendered fresh into `/var/lib/soularr/` on every run, because Lidarr's API
key is minted at first run and only exists in its `config.xml`.

## Known limitation: slskd takes no incoming connections

The NAS runs Mullvad as a full tunnel (`homelab/mullvad.nix`), and **Mullvad removed port
forwarding entirely in 2023**. slskd therefore registers its Mullvad exit IP with the
Soulseek server, and nothing can dial in to it.

A port forward on `optiplex-fw` does **not** fix this — peers never try the LAN WAN IP.

Downloading still works (we dial out). Uploads and share visibility are degraded, which on a
reciprocal network like Soulseek means some peers will deprioritise us. If that becomes a
problem the fix is split-tunnelling slskd out of Mullvad, which is a separate change.

## What is provisioned vs. what you click

`lidarr-provision.service` converges two things over Lidarr's REST API on every boot and
rebuild, reading state first and POSTing only what is missing:

- the music root folder `/mnt/storage/media/music`
- the Transmission download client (category `lidarr`)

It builds the Transmission payload from `GET /api/v1/downloadclient/schema` rather than a
hand-written field list, so a Lidarr upgrade that renames a field cannot silently produce a
half-configured client. There is no stamp file (unlike `bazarr-provision.nix`) because
convergence is structural. The flip side: **deleting either from Lidarr's UI is not
durable** — the next boot puts it back.

Everything else is a one-time manual pass:

1. **Jellyfin** → Dashboard → Libraries → Add Media Library → *Music* → `/mnt/storage/media/music`.
2. **slskd** (`slskd.lan`) → log in with `SLSKD_USERNAME` / `SLSKD_PASSWORD` → confirm it
   shows *Connected* to the Soulseek network.
3. **Prowlarr** (`prowlarr.lan`) → add music indexers → Settings → Apps → add Lidarr → Sync.
4. **Ombi** (`ombi.lan`) → first-run wizard → Media Server = Jellyfin
   (`http://127.0.0.1:8096` + API key) → import Jellyfin users → Settings → Lidarr
   (`http://127.0.0.1:8686` + API key, pick the quality/metadata profile and the music root
   folder) → enable Music requests.

Ombi has no declarative settings surface, so this is the same situation as Jellyseerr.

## Secrets

`secrets/optiplex-nas.yaml` holds `slskd-credentials`, consumed as slskd's `EnvironmentFile`:

```
SLSKD_SLSK_USERNAME   slsknet.org account
SLSKD_SLSK_PASSWORD
SLSKD_USERNAME        slskd web UI login
SLSKD_PASSWORD
```

The slskd **API key** used by soularr is deliberately *not* a secret — it is a plain value in
`homelab/slskd.nix`, pinned to `127.0.0.1/32`. It only grants API access from this machine,
and anyone who can read the nix store already has a shell here.

## Troubleshooting

```bash
systemctl status lidarr navidrome ombi slskd
systemctl status lidarr-provision          # oneshot, RemainAfterExit
journalctl -u lidarr-provision -n 50       # prints rejected payloads verbatim
systemctl status soularr                   # long-running, not a timer
journalctl -u soularr -n 100               # container stdout lands here
```

- **soularr logs "Search failed" / "Failed to enqueue" for everything.** Check slskd's own
  log for `Unauthorized request from IP address ::ffff:127.0.0.1`. slskd reports a loopback
  client as the **IPv4-mapped IPv6 address** `::ffff:127.0.0.1`, which never matches a plain
  IPv4 `127.0.0.1/32` network because the address families differ — so *every* API call
  401s, and soularr reports that as a failed search rather than an auth error. The api_key
  `cidr` in `homelab/slskd.nix` must include `::ffff:127.0.0.1/128`. Verify directly with:

  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' -H "X-API-Key: <key>" http://127.0.0.1:5030/api/v0/session
  ```

- **Nothing imports from Soulseek.** Check `journalctl -u soularr`. The usual cause is a
  permission mismatch: `ls -ld /mnt/storage/downloads/{slskd,lidarr}` must show
  `drwxrwsr-x ... media`, and `id -nG slskd` must include `media`. Downloaded files should
  be `slskd:media` mode `rw-rw-r--`.

- **Lidarr logs `UnauthorizedAccessException ... Permission denied` on every track, and the
  import rolls back.** Lidarr *copies* the tracks into the library fine and then cannot
  unlink the sources, so it reverts the whole import — the tell-tale state is files present
  in both `media/music/` and `downloads/slskd/` but `trackfile` count still 0. Cause: the
  album folder soularr created is `drwxr-sr-x`, i.e. no group write. systemd's `UMask=0002`
  does not reach inside a container — Docker gives the process its own `0022` — so
  `homelab/soularr.nix` wraps the image entrypoint with `umask 0002`. Verify the *running*
  process, not a `docker exec` shell (which gets its own fresh umask):

  ```bash
  grep -i umask /proc/$(docker inspect soularr --format '{{.State.Pid}}')/status   # want 0002
  ```

- **An album is monitored but never appears in Lidarr's wanted list.** Lidarr's
  `wanted/missing` requires the **artist** to be monitored too, not just the album. Adding an
  artist with `addOptions.monitor = "none"` leaves the artist itself unmonitored.
- **Navidrome shows an empty library.** It scans on a schedule; force it from its web UI
  (Settings → scan). Confirm the files are group-readable first.
- **Lidarr grabs nothing from torrents.** That is expected to be patchy — music on public
  indexers is thin, which is the whole reason slskd is here.
